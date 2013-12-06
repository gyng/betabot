class Bot::Adapter::Irc < Bot::Adapter
  attr_accessor :latency

  def initialize(bot)
    require_relative 'message'
    require_relative 'handler'

    @hostname = 'irc.yasashiisyndicate.org'
    @port = 6697
    @settings = {
      ssl: true,
      nick: 'WaruiBot'
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
    @connection = nil
    super
  end

  def connect
    @connection = EM.connect(@hostname, @port, Handler, self, @settings)
  end

  def quit
    @connection.quit(@quit_messages.sample)
    @connection.close_connection_after_writing
  end
  alias :disconnect :quit
  alias :shutdown :quit

  def reconnect
    quit
    connect
  end

  def trigger_plugin(trigger, m)
    case trigger
    when 'reconnect'; reconnect
    when 'quit'; quit
    end
    super(trigger, m)
  end
end