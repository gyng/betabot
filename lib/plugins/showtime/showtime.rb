class Bot::Plugin::Showtime < Bot::Plugin
  require 'cgi'
  require 'uri'
  require 'time'
  require 'timeout'

  def initialize(bot)
    @s = {
      trigger: { showtime: [
        :showtime, 0,
        'showtime <showname> - Returns airing details of matching anime from anilist.co'
      ] },
      anilist: {
        client_id: 'https://anilist.co/settings/developer',
        client_secret: 'https://anilist.co/settings/developer'
      },
      subscribe: false
    }

    @anilist = {
      endpoints: {
        anime: 'https://anilist.co/api/anime',
        search: 'https://anilist.co/api/anime/search',
        token: 'https://anilist.co/api/auth/access_token'
      },
      max_results: 5,
      token: nil
    }

    super(bot)
  end

  def showtime(m)
    refresh_anilist_token if !valid_anilist_token?
    query = m.args[0..-1].join(' ').force_encoding('UTF-8')
    # rubocop:disable Lint/UriEscapeUnescape
    candidates_uri = URI.parse(URI.escape("#{@anilist[:endpoints][:search]}/#{query}"))
    # rubocop:enable Lint/UriEscapeUnescape
    candidates_res = get_anilist_api(candidates_uri)

    if candidates_res.is_a? Net::HTTPSuccess
      candidates = JSON.parse(candidates_res.body, symbolize_names: true)

      m.reply 'Show not found.' if !candidates.is_a? Array

      candidate_ids = candidates.select { |c| c[:airing_status] == 'currently airing' }
                                .map { |c| c[:id] }

      m.reply "No currently airing shows were found for 「#{query}」." if candidate_ids.empty?

      candidate_ids[0..@anilist[:max_results]].each do |id|
        # rubocop:disable Lint/UriEscapeUnescape
        anime_uri = URI.parse(URI.escape("#{@anilist[:endpoints][:anime]}/#{id}"))
        # rubocop:enable Lint/UriEscapeUnescape
        m.reply prettify(JSON.parse(get_anilist_api(anime_uri).body, symbolize_names: true))
      end
    else
      m.reply "Failed to connect to Anilist: #{candidates_res}"
    end
  end

  def get_anilist_api(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.get(uri,
             'authorization' => "Bearer #{@anilist[:token][:access_token]}")
  end

  def valid_anilist_token?
    token = @anilist[:token]
    return token[:expires] > Time.now.to_i if token && token[:expires]

    false
  end

  def refresh_anilist_token
    uri = URI(@anilist[:endpoints][:token])
    res = Net::HTTP.post_form(uri, 'grant_type' => 'client_credentials',
                                   'client_id' => @s[:anilist][:client_id],
                                   'client_secret' => @s[:anilist][:client_secret])
    if res.is_a? Net::HTTPSuccess
      parsed = JSON.parse(res.body, symbolize_names: true)

      if parsed[:access_token].nil?
        Bot.log.warn 'Showtime: Failed to obtain Anilist auth token'
        return false
      end

      @anilist[:token] = parsed

      true
    end
  rescue StandardError => e
    Bot.log.warn "Showtime: Failed to obtain Anilist auth token #{e}"
    false
  end

  def prettify(s)
    "#{s[:title_romaji].to_s.bold} (#{s[:title_japanese]}) " \
    "episode #{s[:airing][:next_episode].to_s.bold} airs in " \
    "#{seconds_to_string(s[:airing][:countdown]).bold} at " \
    "#{s[:airing][:time]} ・ " \
    "#{s[:total_episodes]}×#{s[:duration]}"
  end

  def seconds_to_string(s)
    m = (s / 60).floor
    s = s % 60
    h = (m / 60).floor
    m = m % 60
    d = (h / 24).floor
    h = h % 24
    s = s.floor

    "#{d.to_s + 'd ' if d.positive?}" \
    "#{h.to_s + 'h ' if h.positive?}" \
    "#{m.to_s + 'm ' if m.positive?}" \
    "#{s.to_s + 's' if s.positive?}"
  end
end
