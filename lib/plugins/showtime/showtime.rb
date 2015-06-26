class Bot::Plugin::Showtime < Bot::Plugin
  require 'uri'
  require 'time'
  require 'timeout'

  def initialize(bot)
    @s = {
      trigger: { showtime: [
        :showtime, 0,
        'showtime <showname> - Returns airing details of matching anime ' +
        'from anime.yshi.org'
      ]},
      subscribe: false
    }

    @yshi = {
      base: 'http://anime.yshi.org/api/calendar',
      next_airing: '/next?name=',
      now_airing: '/airing'
    }

    super(bot)
  end

  def showtime(m)
    filter = m.args.join(' ')

    if is_up?(@yshi[:base], 3)
      show = get_showtime(filter)

      if show.nil?
        m.reply "No matching show found."
      else
        now_airing = is_airing(show.title)
        m.reply now_airing.pretty_now_airing if now_airing
        m.reply show.pretty
      end
    else
      m.reply 'All anime showtime airing services are inaccessible.'
    end
  end

  def get_showtime(filter='')
    doc = open(URI.escape(@yshi[:base] + @yshi[:next_airing] + filter)).read
    hash = JSON.parse(doc, symbolize_names: true)

    return nil if hash.keys.empty?

    Show.from_hash(hash)
  end

  def is_airing(filter='')
    doc = open(@yshi[:base] + @yshi[:now_airing]).read
    res = JSON.parse(doc, symbolize_names: true)

    res.map { |s| Show.from_hash(s) }
       .select { |v| v.title =~ Regexp.new(filter, Regexp::IGNORECASE) }
       .first
  end

  # Giant hack just to be able to set custom timeout: net/http does not respect connect_timeout
  # and therefore takes 20 seconds just to declare a site dead
  def is_up?(url, timeout = 3)
    host = URI.parse(URI.escape(url)).host
    port = URI.parse(URI.escape(url)).port

    begin
      http = Net::HTTP.start(host, port, {open_timeout: timeout, read_timeout: timeout})
      begin
        response = http.head("/")
        if response.code == "200"
          # everything fine
          return true
        else
          # unexpected status code
          return false
        end
      rescue Timeout::Error
        # timeout reading from server
        return false
      end
    rescue Timeout::Error
      # timeout connecting to server
      return false
    rescue SocketError
      # unknown server
      return false
    end
  end

  class Show
    attr_accessor :title
    attr_accessor :station
    attr_accessor :start_time
    attr_accessor :end_time
    attr_accessor :eta
    attr_accessor :end_eta
    attr_accessor :episode
    attr_accessor :episode_name
    attr_accessor :delay
    attr_accessor :comment

    def initialize
      yield self if block_given?
    end

    def self.from_hash(hash)
      start_time = DateTime.strptime(hash[:start_time].to_s, '%s')
      end_time = DateTime.strptime(hash[:end_time].to_s, '%s')

      Show.new do |s|
        s.title = hash[:title_name]
        s.station = hash[:channel_name]
        s.start_time = start_time
        s.end_time = end_time
        s.eta = hash[:start_time].to_i - Time.now.utc.to_i
        s.end_eta = hash[:end_time].to_i - Time.now.utc.to_i
        s.episode = hash[:count]
        s.episode_name = hash[:episode_name]
        s.delay = hash[:start_offset]
        s.comment = hash[:comment]
      end
    end

    def pretty
      s = []
      s.push @title.bold if @title
      s.push "episode #{@episode.bold}" if @episode
      s.push "— #{@episode_name}" if @episode_name && !@episode_name.empty?
      s.push "airs in #{seconds_to_string(@eta).bold}" if @eta
      s.push "on #{@station}" if @station
      s.push "(#{@start_time})" if @start_time
      s.push " delayed #{seconds_to_string(@delay)}" if @delay && @delay > 0
      s.join(' ')
    end

    def pretty_now_airing
      s = []
      s.push @title.bold if @title
      s.push "episode #{@episode.bold}" if @episode
      s.push "— #{@episode_name}" if @episode_name && !@episode_name.empty?
      s.push "is now airing on #{@station}" if @station
      s.push "and ends in #{seconds_to_string(@end_eta).bold}" if @end_eta
      s.join(' ').green
    end

    private

    def seconds_to_string(s)
      m = (s / 60).floor
      s = s % 60
      h = (m / 60).floor
      m = m % 60
      d = (h / 24).floor
      h = h % 24
      s = s.floor

      "#{d.to_s + 'd ' if d > 0}" +
      "#{h.to_s + 'h ' if h > 0}" +
      "#{m.to_s + 'm ' if m > 0}" +
      "#{s.to_s + 's' if s > 0}"
    end
  end
end
