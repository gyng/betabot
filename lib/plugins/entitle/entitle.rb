class Bot::Plugin::Entitle < Bot::Plugin
  require 'nokogiri'
  require 'open-uri'
  require 'timeout'

  def initialize(bot)
    @s = {
      trigger: { entitle: [
        :call, 0,
        'entitle list, entitle add <filter>, entitle delete <filter>. ' \
        'Filters are regular expressions. Using these filters ' \
        'Entitle looks for uninformative URLs and blurts their titles out.'
      ] },
      subscribe: true,
      timeout: 10,
      filters: [
        'http.*?google\.com\S*',
        'http.+?=.\S+',
        'http.+\/\d+\/?[^\.]+$',
        'http.*?youtu\.be.\S+'
      ],
      user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:67.0) Gecko/20100101 Firefox/68.0',
      curl_user_agent: 'curl/7.68.0'
    }
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
    user_agent = curl_needed?(url) ? @s[:curl_user_agent] : @s[:user_agent]

    response = RestClient.get(url, user_agent: user_agent).body
    doc = Nokogiri::HTML(response)
    doc.encoding = 'utf-8'

    # Resume regular web-citizen processing
    html_title = doc.at_css('title').text.gsub(/ *\n */, ' ').strip
    meta_desc = (doc.at("meta[name='description']") || {})['content']
    meta_og_title = (doc.at("meta[property='og:title']") || {})['content']
    meta_og_desc = (doc.at("meta[property='og:description']") || {})['content']
    meta_og_twitter_title = (doc.at("meta[property='twitter:title']") || {})['content']

    html_title || meta_og_title || meta_og_twitter_title || meta_desc || meta_og_desc
  end

  def curl_needed?(url)
    # Special handling needed for cerntain popular sites
    # https://stackoverflow.com/a/30795206
    # rubocop:disable Metrics/LineLength
    youtube_url_regex = %r{^(?:https?:\/\/)?(?:youtu\.be\/|(?:www\.|m\.)?youtube\.com\/(?:watch|v|embed)(?:\.php)?(?:\?.*v=|\/))([a-zA-Z0-9\-_]+)}
    twitter_url_regex = %r{^(?:https?:\/\/)?(?:www\.)?twitter\.com\/([a-zA-Z0-9_]+)}
    # rubocop:enable Metrics/LineLength
    is_youtube_url = url.match(youtube_url_regex)
    is_twitter_url = url.match(twitter_url_regex)
    Bot.log.info('Entitle: this is a YouTube URL') if is_youtube_url
    Bot.log.info('Entitle: this is a Twitter URL') if is_twitter_url

    is_youtube_url || is_twitter_url
  end
end
