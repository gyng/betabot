class Bot::Plugin::Showtime < Bot::Plugin
  def initialize(bot)
    @s = {
      trigger: { showtime: [
        :showtime, 0,
        'showtime <regex> - Returns airing details of matching anime ' +
        '(up to 3 matches) from mahou Showtime! - http://www.mahou.org/Showtime/.'
      ]},
      subscribe: false
    }
    super(bot)
  end

  def showtime(m)
    m.reply get_showtime(m.args[0])
  end

  def get_showtime(filter)
    doc = Nokogiri::HTML(open('http://www.mahou.org/Showtime/'))
    shows_raw = doc.xpath("//table[@summary='Currently Airing']//table/tr").to_a
    # shift - 0 is table heading, get rid of it
    shows_raw.shift
    # Add shows starting soon
    shows_starting_soon_raw = doc.xpath("//table[@summary='Starting Soon']//table/tr").to_a
    shows_starting_soon_raw.shift
    shows_raw.concat(shows_starting_soon_raw)

    shows = Hash.new
    shows_raw.each { |show|
      begin
        # Can you modernise your god damned site
        show_obj = Show.new
        show_obj.title        = show.children[2].children[0].to_s.strip
        show_obj.season       = show.children[4].children[0].to_s.strip
        show_obj.station      = show.children[6].children[0].to_s.strip
        show_obj.company      = show.children[8].children[0].to_s.strip
        show_obj.airtime      = show.children[10].children[0].to_s.strip
        show_obj.eta          = is_eta?(show.children[12].children[0].to_s.strip) || is_eta?(show.children[16].children[0].to_s.strip)
        show_obj.episodes     = show.children[14].children[0].to_s.strip
        show_obj.anidb_link   = show.children[-2].children[1].get_attribute('href').to_s if !show.children[-2].children[1].nil?
        website_link          = show.children[-2].children[3].to_a  if !show.children[-2].children[3].nil?
        show_obj.website_link = website_link[0][1] if !website_link.empty?

        shows["#{show_obj.title}"] = show_obj
      rescue
        next
      end
    }

    matching_keys = shows.keys.grep(Regexp.new(filter, Regexp::IGNORECASE))

    if matching_keys.empty?
      return @noShowMsg
    else
      rs = Array.new

      0.upto([matching_keys.size, 3].min-1) { |i|
         rs.push(prettifyShow(shows[matching_keys[i]]))
      }

      return rs.join("\n")
    end
  end

  def prettifyShow(show)
    # prettifyShow is dumped here instead of being in Show so it has access to bold()
    return nil if (!show.is_a? Show)
    return "#{show.title.bold} airs in #{show.eta.bold} on #{show.station} (#{show.airtime}) - #{show.website_link}"
  end

  def is_eta?(s)
    s =~ /\dd|\dh|\dm/ ? s : false
  end

  class Show
    attr_accessor :title
    attr_accessor :season
    attr_accessor :station
    attr_accessor :company
    attr_accessor :airtime
    attr_accessor :eta
    attr_accessor :episodes
    attr_accessor :anidb_link
    attr_accessor :website_link

    def to_s
      return [title, season, station, company, airtime, eta, episodes, anidb_link, website_link].join(", ")
    end
  end
end