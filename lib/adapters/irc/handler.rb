class Bot::Adapter::Irc::Handler < EM::Connection
  require_relative 'rfc2812'
  include Bot::Adapter::Irc::RFC2812

  attr_accessor :state

  def initialize(adapter, s=Hash.new(false))
    @adapter = adapter
    @s = s
    @registered = false
    @state = :disconnected
    @buffer = BufferedTokenizer.new("\r\n")
  end

  def connection_completed
    start_tls if @s[:ssl]
    register(@s[:nick])
    keep_alive
    @state = :connected
  end

  def send_data(data)
    Bot.log.info "#{self.class.name} #{@s[:name]}\n\t#{'->'.green} #{data}"
    super @adapter.format(data) + "\n"
  rescue Exception => e
    Bot.log.error "#{self.class.name} #{@s[:name]}\n#{e}\n#{e.backtrace.join("\n")}}"
  end

  alias_method :send, :send_data

  def receive_data(data)
    data = @buffer.extract(data)
    data.each do |line|
      Bot.log.info "#{self.class.name} #{@s[:name]}\n\t#{'<-'.cyan} #{line.chomp}"
      handle_message(parse_data(line))
    end
  rescue Exception => e
    Bot.log.error "#{self.class.name} #{@s[:name]}\n#{e}\n#{e.backtrace.join("\n")}}"
  end

  def parse_data(data)
    sender, real_name, hostname, type, channel = nil
    privm_regex = /^:(?<sender>.+)!(?<real_name>.+)@(?<hostname>.+)/
    origin      = self
    raw         = data
    text        = data.split(' :').last.chomp
    data        = data.split(' ')
    internal_type = :server

    if data[0] == 'PING'
      type      = :ping
      sender    = data[1]
    elsif data[1] == 'PONG'
      type      = :pong
      sender    = data[0]
      channel   = data[2]
    elsif data[1] == 'PRIVMSG'
      type      = :privmsg
      matches   = data[0].match(privm_regex)
      sender    = matches[:sender]
      real_name = matches[:real_name]
      hostname  = matches[:hostname]
      channel   = data[2]
      # Handle PMs - reply to user directly.
      channel   = ((data[2] == @s[:nick]) ? matches[:sender] : data[2])
      internal_type = :client
    elsif /^(JOIN|PART)$/ === data[1]
      type      = data[1].downcase.to_sym
      matches   = data[0].match(privm_regex)
      sender    = matches[:sender]
      real_name = matches[:real_name]
      hostname  = matches[:hostname]
      channel   = data[2].gsub(/^:/, '')
    elsif /^\d+$/ === data[1]
      # If message type is numeric
      type      = data[1].to_sym
      sender    = data[0].delete(':')
      channel   = data[2]
    end

    Bot::Adapter::Irc::Message.new do |m|
      m.type      = type
      m.sender    = sender
      m.real_name = real_name
      m.hostname  = hostname
      m.channel   = channel
      m.text      = text
      m.raw       = raw
      m.origin    = origin
      m.internal_type = internal_type
    end
  end

  def handle_message(m)
    case m.type
    when :ping
      send "PONG #{m.sender} #{m.text}"
    when :pong
      @state = :connected
      @adapter.latency = (Time.now.to_f - m.text.to_f) * 1000
    when :"001"
      @registered = true
      @s[:default_channels].each { |c| join(c) }
    when :"433"
      nick = m.raw.split(' ')[3]
      register(nick + '_')
      EM.add_timer(900) { nick(@s[:nick]) } # Try to reclaim desired nick
    when :privmsg
      check_trigger(m)
    end

    @adapter.publish(m)
  end

  def check_trigger(m)
    if /^#{Bot::SHORT_TRIGGER}([^ ]*)/i === m.text || # !command
       /^#{@s[:nick]}: ([^ ]*)/i        === m.text    # BotNick: command
      trigger = $1
      @adapter.trigger_plugin(trigger, m)
    end
  end

  def register(nick)
    nick(nick)
    user(nick, 0, ":Romani ite domum")
  end

  def keep_alive
    period_timer = EventMachine::PeriodicTimer.new(300) do
      if @state == :connected
        send "PING #{Time.now.to_f}"
        @state = :waiting
        EM.add_timer(30) do
          if @state == :waiting
            @state = :reconnecting
            @adapter.reconnect
          end
        end
      else
        period_timer.cancel
      end
    end
  end

  def unbind
    if (@state == :connected || @state == :waiting) && !($shutdown || $restart)
      Bot.log.warn "Connection closed: reconnecting in 30 seconds..."
      @state = :reconnecting
      EM.add_timer(30) { @adapter.reconnect(@s[:name]) if @state == :reconnecting }
    else
      @state = :disconnected
    end
  end
end