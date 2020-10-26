class Bot::Adapter::Irc < Bot::Adapter
  attr_accessor :latency
  attr_accessor :handler

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

  # server_name.channel
  # eg. myserver.#mychannel
  def prepare_message(irc_addr)
    combo = irc_addr.split('.')

    if combo.length != 2
      Bot.log.info("IRC: Bad address #{irc_addr}")
      return
    end

    server, target = combo
    conn = @connections[server.to_sym]

    if !conn
      Bot.log.error("IRC: Cannot find connection named #{server}")
      return
    end

    conn.prepare_privmsg(target)
  end

  def connect(regex = '.*')
    selected = @s[:servers].select { |s| s[:name].match(/#{regex}/i) }

    selected.each do |s|
      host = s[:hostname].sample
      Bot.log.info "IRC: Connecting to #{host}..."
      @handler = EM.connect(host, s[:port], Handler, self, s)
      @connections[s[:name].to_sym] = @handler
    rescue StandardError => e
      EM.add_timer(@reconnect_delay) { connect(s[:name]) }
      Bot.log.warn "Failed to connect to server #{s[:name]}: #{e}, retrying in #{@reconnect_delay}s"
    end
  end

  def on_connect(conn)
    @bot.on_connect(self, conn)
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

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def trigger_plugin(trigger, m)
    case trigger
    when 'reconnect' then reconnect if @bot.auth(4, m)
    when 'disconnect' then quit if @bot.auth(4, m)
    when 'join' then m.origin.join(m.args[0], m.args[1] || []) if @bot.auth(4, m)
    when 'part' then m.origin.part(m.args[0], m.args[1] || '') if @bot.auth(4, m)
    when 'nick' then m.origin.nick(m.args[0]) if @bot.auth(4, m)
    when 'defaultchan-add'
      if @bot.auth(4, m)
        server = m.args[0]
        channel = m.args[1]
        target = @s[:servers].find { |s| s[:name] == server }
        if target
          target[:default_channels].push(channel).uniq
          save_settings
          m.reply 'Updated default channels.'
        else
          m.reply 'Could not add default channel. Check server group.'
        end
      end
    when 'defaultchan-rm'
      if @bot.auth(4, m)
        server = m.args[0]
        channel = m.args[1]
        target = @s[:servers].find { |s| s[:name] == server }
        if target
          found = target[:default_channels].delete(channel)
          if found
            save_settings
            m.reply 'Updated default channels.'
          else
            m.reply 'Could not remove default channel. Check channel name.'
          end
        else
          m.reply 'Could not remove default channel. Check server group.'
        end
      end
    when 'defaultchan-ls'
      m.reply @s[:servers].to_s if @bot.auth(4, m)
    end

    super(trigger, m)
  end
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity

  def format(string)
    zwnj = "\u{0200c}"
    ansi_to_irc_table = {
      "\033[30m" => "\x031#{zwnj}",  # black
      "\033[31m" => "\x034#{zwnj}",  # red
      "\033[32m" => "\x033#{zwnj}",  # green
      "\033[33m" => "\x037#{zwnj}",  # brown
      "\033[34m" => "\x032#{zwnj}",  # blue
      "\033[35m" => "\x0313#{zwnj}", # magenta
      "\033[36m" => "\x0311#{zwnj}", # cyan
      "\033[37m" => "\x031#{zwnj}", # gray
      "\033[0m" => "\x03#{zwnj}", # color end
      "\033[1m" => "\x02#{zwnj}", # bold start
      "\033[22m" => "\x02#{zwnj}" # bold end
    }

    s = string.to_s
    ansi_to_irc_table.each { |ansi, irc| s.gsub!(ansi, irc) }
    s
  end
end
