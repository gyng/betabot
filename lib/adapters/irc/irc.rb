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
          hostname: 'irc.yasashiisyndicate.org',
          port: 6697,
          ssl: true,
          nick: 'WaruiBot',
          default_channels: ['#fauxbot', '#dicks']
        }
      ]
    }

    @quit_messages = [
      'Goodbye, world!',
      'さようなら、世界！',
      '안녕, 세계!',
      '再见，世界！',
      '再見，世界！',
      'وداعا، العالم!',
      'Vaarwel, wereld!',
      'Adiaŭ, mondo!',
      'Addio, mondo!',
      'Adiós, mundo!',
      'Adieu, monde!',
      'Goodbye, dunia!',
      'Hej då, världen!',
      'זייַ געזונט, וועלט!',
      'שלום, עולם!',
      'Selamat tinggal, dunia!',
      'Αντίο, κόσμο!',
      'Auf Wiedersehen, Welt!',
      'अलविदा, दुनिया!',
      'Прощай, мир!',
      'Salve, per omnia saecula!',
      'Hyvästi, maailma!',
      'Kveðja, heimur!'
    ]

    @bot = bot
    @connections = {}
    super
  end

  def connect(regex='.*')
    selected = @s[:servers].select { |s| s[:name].match(/#{regex}/i) }

    selected.each do |s|
      @connections[s[:name].to_sym] = EM.connect(s[:hostname], s[:port], Handler, self, s)
    end
  end

  def quit(regex='.*')
    selected = @connections.select { |k, v| k.to_s.match(/#{regex}/i) }

    selected.each_value do |c|
      c.quit(@quit_messages.sample)
      c.close_connection_after_writing
      @connections.delete(c)
    end
  end
  alias :disconnect :quit
  alias :shutdown :quit

  def reconnect(regex='.*')
    quit(regex)
    connect(regex)
  end

  def trigger_plugin(trigger, m)
    case trigger
    when 'reconnect'; reconnect
    when 'quit'; quit
    end
    super(trigger, m)
  end
end