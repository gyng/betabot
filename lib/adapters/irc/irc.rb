class Bot::Adapter::Irc < Bot::Adapter
  attr_accessor :latency

  def initialize(bot)
    require_relative 'message'
    require_relative 'handler'

    # Default settings
    @s = {
      servers: [
        {
          enabled: true,
          name: 'yasashii',
          hostname: ['irc.rizon.net'],
          port: 6697,
          ssl: true,
          nick: 'HuddaBot',
          default_channels: ['#hudda', '#huddabot']
        }
      ]
    }

    @quit_messages = [
      'Goodbye, world!', 'さようなら、世界！', '안녕, 세계!', '再见，世界！', '再見，世界！', 'وداعا، العالم!', 'Vaarwel, wereld!',
      'Adiaŭ, mondo!', 'Addio, mondo!', 'Adiós, mundo!', 'Adieu, monde!', 'Goodbye, dunia!', 'Hej då, världen!',
      'זייַ געזונט, וועלט!', 'שלום, עולם!', 'Selamat tinggal, dunia!', 'Αντίο, κόσμο!', 'Auf Wiedersehen, Welt!',
      'अलविदा, दुनिया!', 'Прощай, мир!', 'Salve, per omnia saecula!', 'Hyvästi, maailma!', 'Kveðja, heimur!'
    ]

    @reconnect_delay = 20
    @bot = bot
    @connections = {}
    super
  end

  def connect(regex = '.*')
    selected = @s[:servers].select { |s| s[:name].match(/#{regex}/i) }

    selected.each do |s|
      begin
        host = s[:hostname].sample
        Bot.log.info "IRC: Connecting to #{host}..."
        @connections[s[:name].to_sym] = EM.connect(host, s[:port], Handler, self, s)
      rescue StandardError => e
        EM.add_timer(@reconnect_delay) { connect(s[:name]) }
        Bot.log.warn "Failed to connect to server #{s[:name]}: #{e}, retrying in #{@reconnect_delay}s"
      end
    end
  end

  def quit(regex = '.*')
    selected = @connections.select { |k, _| k.to_s.match(/#{regex}/i) }

    selected.each_value do |c|
      begin
        c.quit(@quit_messages.sample) if c.state != :reconnecting
        c.state = :quitting
      rescue StandardError => e
        Bot.log.warn "Failed to quit connection: #{e}, continuing..."
      end
      c.close_connection if c.state != :disconnected
      @connections.delete(c)
    end
  end

  alias disconnect quit
  alias shutdown quit

  def reconnect(regex = '.*')
    quit(regex)
    connect(regex)
  end

  def trigger_plugin(trigger, m)
    case trigger
    when 'reconnect' then reconnect
    when 'disconnect' then quit
    when 'join' then m.origin.join(m.args[0], m.args[1] || []) if @bot.auth(4, m)
    when 'part' then m.origin.part(m.args[0], m.args[1] || '') if @bot.auth(4, m)
    when 'nick' then m.origin.nick(m.args[0])
    end
    super(trigger, m)
  end

  def format(string)
    ansi_to_irc_table = {
      "\033[30m" => "\x031",  # black
      "\033[31m" => "\x034",  # red
      "\033[32m" => "\x033",  # green
      "\033[33m" => "\x037",  # brown
      "\033[34m" => "\x032",  # blue
      "\033[35m" => "\x0313", # magenta
      "\033[36m" => "\x0311", # cyan
      "\033[37m" => "\x0314", # gray
      "\033[0m"  => "\x03",   # color end
      "\033[1m"  => "\x02",   # bold start
      "\033[22m" => "\x02"    # bold end
    }

    s = string.to_s
    ansi_to_irc_table.each { |ansi, irc| s.gsub!(ansi, irc) }
    s
  end
end
