class Bot::Plugin::Showtime < Bot::Plugin
  require 'uri'
  require 'time'
  require 'timeout'

  def initialize(bot)
    @s = {
      trigger: { showtime: [
        :showtime, 0,
        'showtime <regex> - Returns airing details of matching anime ' +
        '(up to 3 matches) from mahou Showtime! - http://www.mahou.org/Showtime/'
      ]},
      subscribe: false
    }

    @mahou = 'http://www.mahou.org/Showtime/'

    super(bot)
  end

  def showtime(m)
    filter = m.args.join(' ')

    if is_up?(@mahou, 3)
      m.reply pretty(get_showtime(filter))
    else
      m.reply 'All anime showtime airing services are inaccessible.'
    end
  end

  def get_showtime(filter='.*')
    doc = Nokogiri::HTML(open(@mahou))
    shows_raw = doc.xpath("//table[@summary='Currently Airing']//table/tr").to_a
    shows_raw.shift # First element is table heading, get rid of it

    # Add shows starting soon to currently airing
    shows_starting_soon_raw = doc.xpath("//table[@summary='Starting Soon']//table/tr").to_a
    shows_starting_soon_raw.shift
    shows_raw.concat(shows_starting_soon_raw)

    shows = []
    shows_raw.each do |show|
      begin
        # Please modernise your site
        show_obj = Show.new do |s|
          s.title        = show.children[2].children[0].to_s.strip
          s.season       = show.children[4].children[0].to_s.strip
          s.station      = show.children[6].children[0].to_s.strip
          s.company      = show.children[8].children[0].to_s.strip
          s.airtime      = show.children[10].children[0].to_s.strip
          s.eta          = is_eta?(show.children[12].children[0].to_s.strip) || is_eta?(show.children[16].children[0].to_s.strip)
          s.episodes     = show.children[14].children[0].to_s.strip
          s.anidb_link   = show.children[-2].children[1].get_attribute('href').to_s if !show.children[-2].children[1].nil?
          website_link   = show.children[-2].children[3].to_a if !show.children[-2].children[3].nil?
          s.website_link = website_link[0][1] if website_link && !website_link.empty?
        end

        shows.push(show_obj)
      rescue
        next
      end
    end

    matched_shows = shows.select { |v| v.title =~ Regexp.new(filter, Regexp::IGNORECASE) }
    matched_shows.first(3)
  end

  def is_eta?(s)
    # Matches 4d 3h 41m or 4d 41m
    s =~ /\dd|\dh|\dm/ ? s : false
  end

  # Giant hack just to be able to set custom timeout: net/http does not respect connect_timeout
  # and therefore takes 20 seconds just to declare a site dead
  def is_up?(url, timeout = 3)
    host = URI.parse(url).host
    port = URI.parse(url).port

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

  def pretty(shows)
    if shows.empty?
      'No matching show was found.'
    else
      shows.map { |s| s.pretty }.join("\n")
    end
  end

  def seconds_to_string(s)
    m = (s / 60).floor
    s = s % 60
    h = (m / 60).floor
    m = m % 60
    d = (h / 24).floor
    h = h % 24
    s = s.floor

    "#{d.to_s + 'd, ' if d > 0}" +
    "#{h.to_s + 'h, ' if h > 0}" +
    "#{m.to_s + 'm, ' if m > 0}" +
    "#{s.to_s + 's' if s > 0}"
  end

  class Show
    attr_accessor :title
    attr_accessor :season
    attr_accessor :station
    attr_accessor :company
    attr_accessor :airtime
    attr_accessor :eta
    attr_accessor :episode
    attr_accessor :episodes
    attr_accessor :anidb_link
    attr_accessor :website_link

    def initialize
      yield self if block_given?
    end

    def pretty
      s = []
      s.push @title.bold if @title
      s.push "episode #{@episode.bold}" if @episode
      s.push "airs in #{@eta.bold}" if @eta
      s.push "on #{@station}" if @station
      s.push "(#{@airtime})" if @airtime
      s.push "- #{@website_link}" if @website_link
      s.join(' ')
    end
  end
end
