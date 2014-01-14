class Bot::Plugin::Showtime < Bot::Plugin
  def initialize(bot)
    @s = {
      trigger: { showtime: [
        :showtime, 0,
        'showtime <regex> - Returns airing details of matching anime ' +
        '(up to 3 matches) from mahou Showtime! - http://www.mahou.org/Showtime/ and gesopls - http://gesopls.de/abc/.'
      ]},
      subscribe: false
    }
    super(bot)
  end

  def showtime(m)
    m.reply get_showtime(*m.args)
  end

  def get_showtime(filter='.*')
    doc = Nokogiri::HTML(open('http://www.mahou.org/Showtime/'))
    shows_raw = doc.xpath("//table[@summary='Currently Airing']//table/tr").to_a
    shows_raw.shift # First element is table heading, get rid of it

    # Add shows starting soon to currently airing
    shows_starting_soon_raw = doc.xpath("//table[@summary='Starting Soon']//table/tr").to_a
    shows_starting_soon_raw.shift
    shows_raw.concat(shows_starting_soon_raw)

    shows = {}
    shows_raw.each do |show|
      begin
        # Can you modernise your god damned site
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
          s.website_link = website_link[0][1] if !website_link.empty?
        end

        shows["#{show_obj.title}"] = show_obj
      rescue
        next
      end
    end

    # matched_keys is a Hash of show_title => show_object
    matched_keys = shows.keys.grep(Regexp.new(filter, Regexp::IGNORECASE))
    pretty_shows = []

    matched_keys.each do |k|
      pretty_shows.push(shows[k].add_gesopls_info.pretty)
      break if pretty_shows.size >= 3
    end

    pretty_shows.empty? ? 'No shows were matched.' : pretty_shows.join("\n")
  end

  def is_eta?(s)
    # Matches 4d 3h 41m or 4d 41m
    s =~ /\dd|\dh|\dm/ ? s : false
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

    def add_gesopls_info
      query = URI.encode(@title.gsub(/\W/, ' ').split(' ').first)
      doc = Nokogiri::HTML(open("http://gesopls.de/abc/?name=#{query}&channel=&firstonly=on"))
      ep = doc.css('.episode').to_a[1]
      title = doc.css('.show').to_a[1]
      @title = title.text if title
      @episode = ep.text if ep
      self
    end

    def pretty
      "#{@title.bold}#{@episode ? ' episode ' + @episode.bold : ''} airs in #{@eta.bold} on #{@station} (#{@airtime}) - #{@website_link}"
    end
  end
end