class Bot::Plugin::Entitle < Bot::Plugin
  require 'json'
  require 'nokogiri'
  require 'open-uri'
  require 'timeout'

  def initialize(bot)
    @s = {
      trigger: { entitle: [
        :call, 0,
        'entitle list, entitle add <filter>, entitle delete <filter>, entitle twitch_client_id <id>. ' \
        'Filters are regular expressions. Using these filters ' \
        'Entitle looks for uninformative URLs and blurts their titles out.'
      ] },
      subscribe: true,
      timeout: 20,
      filters: [
        'http.*'
      ],
      user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:77.0) Gecko/20100101 Firefox/77.0',
      curl_user_agent: 'curl/7.68.0',
      # https://dev.twitch.tv/console/apps, redirect to http://localhost
      twitch_client_id: ''
    }
    @twitter_status_regex = %r{^(?:https?://)?(?:www\.|mobile\.)?twitter\.com/([a-zA-Z0-9_]+)/status/(\d+)/?}
    @twitch_stream_regex = %r{^(?:https?://)?(?:www\.)?twitch\.tv/([a-zA-Z0-9_]+)/?}
    super(bot)
  end

  def call(m = nil)
    case m.args[0]
    when 'list'
      m.reply(@s[:filters].join(', '))
    when 'add'
      if @bot.auth(4, m)
        @s[:filters].push(m.args[1])
        save_settings
        m.reply('Filter added.')
      end
    when 'delete'
      if @bot.auth(4, m)
        @s[:filters].delete(m.args[1])
        save_settings
        m.reply('Filter deleted.')
      end
    when 'twitch_client_id'
      if @bot.auth(4, m)
        @s[:twitch_client_id] = m.args[1]
        save_settings
        m.reply('Twitch client ID updated.')
      end
    else
      check_filter(m)
    end
  end

  def receive(m)
    check_filter(m)
  end

  def check_filter(m)
    return if m.text.nil?

    tokens = String.new(m.text).split(' ').uniq
    titles = []

    @s[:filters].each do |regex_s|
      regex = Regexp.new(regex_s)

      tokens.each do |t|
        next if regex.match(t).nil?

        operation = proc {
          Timeout.timeout(@s[:timeout]) do
            get_title(t)
          end
        }
        callback = proc { |title|
          m.reply(title) if !title.nil? && !titles.include?(title)
          titles.push(title)
        }
        errback = proc { |e| Bot.log.info "Entitle: Failed to get title #{e}" }
        EM.defer(operation, callback, errback)
      end
    end
  end

  def get_title(url)
    Bot.log.info("Entitle: getting title of #{url}")

    if url.match(@twitter_status_regex)
      handle_twitter(url)
    elsif url.match(@twitch_stream_regex)
      if !@s[:twitch_client_id]
        Bot.log.info('Entitle: Twitch stream detected but Twitch API key not set up')
        return
      end
      handle_twitch(url)
    else
      handle_default(url)
    end
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def handle_default(url)
    Bot.log.info('Entitle: handling as default URL type')

    user_agent = curl_needed?(url) ? @s[:curl_user_agent] : @s[:user_agent]
    response = RestClient.get(url, user_agent:)
    body = response.body
    doc = Nokogiri::HTML(body)
    doc.encoding = 'utf-8'

    # Resume regular web-citizen processing
    html_title = doc.at_css('title').text.gsub(/ *\n */, ' ').strip if doc.at_css('title')
    meta_desc = (doc.at("meta[name='description']") || {})['content']
    meta_og_title = (doc.at("meta[property='og:title']") || {})['content']
    meta_og_desc = (doc.at("meta[property='og:description']") || {})['content']
    meta_og_twitter_title = (doc.at("meta[property='twitter:title']") || {})['content']

    p doc.at_css('a[href$="https://joinmastodon.org"]')

    # Check special cases that need access to DOM
    is_mastodon = (response.headers[:server] || '').match(/^Mastodon/i) || doc.at_css('.notranslate#mastodon')
    if is_mastodon
      Bot.log.info("Entitle: Actually handling #{url} as Mastodon URL")
      return "#{meta_og_desc.gsub("\n", ' ↵ '.gray)} — #{meta_og_title}"
    end

    meta_og_title || meta_og_twitter_title || html_title || meta_desc || meta_og_desc
  end
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity

  def handle_twitter(url)
    Bot.log.info('Entitle: handling as Twitter tweet')
    matches = url.match(@twitter_status_regex)
    user = matches[1]
    id = matches[2]

    new_url = "https://publish.twitter.com/oembed?url=https://twitter.com/#{user}/status/#{id}"
    response_json = RestClient.get(new_url, user_agent: @s[:user_agent]).body
    response = JSON.parse(response_json, symbolize_names: true)
    html = response[:html].gsub('</p>&mdash; ', '__DASH__')
    html = html.gsub('<br>', '__BR__')

    doc = Nokogiri::HTML(html)
    doc.encoding = 'utf-8'

    tweet = doc.at_css('.twitter-tweet').text.gsub(/ *\n */, ' ').strip
    tweet = tweet.gsub('__BR__', " #{'↵'.gray} ")
    tweet.gsub('__DASH__', ' — ')
  end

  def handle_twitch(url)
    Bot.log.info('Entitle: handling as Twitch channel')
    matches = url.match(@twitch_stream_regex)
    channel = matches[1]
    headers = {
      user_agent: @s[:user_agent],
      'Accept' => 'application/vnd.twitchtv.v5+json',
      'Client-ID' => @s[:twitch_client_id]
    }

    user_api_url = "https://api.twitch.tv/kraken/users?login=#{channel}"
    user_response_json = RestClient.get(user_api_url, headers).body
    user_response = JSON.parse(user_response_json, symbolize_names: true)
    channel_id = user_response[:users][0][:_id]

    api_url = "https://api.twitch.tv/kraken/streams/#{channel_id}"
    response_json = RestClient.get(api_url, headers).body
    response = JSON.parse(response_json, symbolize_names: true)

    if response[:stream]
      display_name = response[:stream][:channel][:display_name]
      title = response[:stream][:channel][:status]
      game = response[:stream][:game]
      is_rerun = response[:stream][:broadcast_platform] == 'other'
      live = is_rerun ? '[RERUN]'.blue : '[LIVE]'.red
      viewers = is_rerun ? '' : ", #{response[:stream][:viewers]} viewers"

      "#{live} #{display_name} — #{title} (#{game}#{viewers})"
    else
      Bot.log.info('Entitle: Twitch channel not live, getting channel info')
      channel_api_url = "https://api.twitch.tv/kraken/channels/#{channel_id}"
      channel_response_json = RestClient.get(channel_api_url, headers).body
      channel_response = JSON.parse(channel_response_json, symbolize_names: true)

      status = channel_response[:status]
      display_name = channel_response[:display_name]
      description = channel_response[:description]
      game = channel_response[:game]
      "#{'[OFFLINE]'.gray} #{display_name} — #{status} (#{game}, #{description})"
    end
  end

  def curl_needed?(url)
    # Special handling needed for cerntain popular sites
    # https://stackoverflow.com/a/30795206
    youtube_url_regex = %r{^(?:https?://)?(?:youtu\.be/|(?:www\.|m\.)?youtube\.com)}
    is_youtube_url = url.match(youtube_url_regex)
    Bot.log.info('Entitle: this is a YouTube URL') if is_youtube_url

    is_youtube_url
  end
end
