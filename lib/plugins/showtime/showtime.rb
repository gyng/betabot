class Bot::Plugin::Showtime < Bot::Plugin
  require 'uri'
  require 'time'
  require 'timeout'

  def initialize(bot)
    @s = {
      trigger: { showtime: [
        :showtime, 0,
        'showtime <showname> - Returns airing details of matching anime from anime.yshi.org'
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
      token: nil
    }

    super(bot)
  end

  def showtime(m)
    refresh_anilist_token if !check_anilist_token
    query = m.args[0..-1].join(' ').force_encoding('UTF-8')
    candidates_uri = URI.parse(URI.escape("#{@anilist[:endpoints][:search]}/#{query}"))
    candidates_res = get_anilist_api(candidates_uri)

    if candidates_res.is_a? Net::HTTPSuccess
      candidates = JSON.parse(candidates_res.body, symbolize_names: true)

      m.reply 'Show not found.' if !candidates.is_a? Array

      candidate_ids = candidates.select { |c| c[:airing_status] == 'currently airing' }
                                .map { |c| c[:id] }

      m.reply "No currently airing shows were found for 「#{query}」." if candidate_ids.empty?

      candidate_ids[0..5].each do |id|
        anime_uri = URI.parse(URI.escape("#{@anilist[:endpoints][:anime]}/#{id}"))
        m.reply prettify(JSON.parse(get_anilist_api(anime_uri).body, symbolize_names: true))
      end
    else
      m.reply 'Failed to connect to Anilist'
    end
  end

  def get_anilist_api(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.get(uri,
             'authorization' => "Bearer #{@anilist[:token][:access_token]}")
  end

  def check_anilist_token
    token = @anilist[:token]
    token && token[:expires] && token[:expires] < Time.now.to_i
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
  rescue => e
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

    "#{d.to_s + 'd ' if d > 0}" \
    "#{h.to_s + 'h ' if h > 0}" \
    "#{m.to_s + 'm ' if m > 0}" \
    "#{s.to_s + 's' if s > 0}"
  end
end
