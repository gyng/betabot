class Bot::Adapter::Irc::Handler < EM::Connection
  require_relative 'rfc2812'
  include Bot::Adapter::Irc::RFC2812

  attr_accessor :state
  attr_reader :timeout
  attr_reader :ping_interval
  attr_reader :reconnect_delay
  attr_reader :nick_reclaim_interval

  def initialize(adapter, s = Hash.new(false))
    @adapter = adapter
    @s = s
    @registered = false
    @state = :disconnected
    @buffer = BufferedTokenizer.new("\r\n")
    @timeout = 30
    @ping_interval = 300
    @nick_reclaim_interval = 900
    @reconnect_delay = 30
  end

  def post_init
    start_tls({ :sni_hostname => @s[:selected_hostname] }) if @s[:ssl]
  end

  def connection_completed
    register(@s[:nick])
    keep_alive
    @state = :connected
  end

  def prepare_privmsg(to)
    Bot::Adapter::Irc::Message.new do |m|
      m.origin = self
      m.type = 'PRIVMSG'
      m.channel = to
    end
  end

  def send_data(data)
    Bot.log.info "#{self.class.name} #{@s[:name]}\n\t#{'->'.green} #{data}"
    super @adapter.format(data) + "\n"
  rescue StandardError => e
    Bot.log.error "#{self.class.name} #{@s[:name]}\n#{e}\n#{e.backtrace.join("\n")}}"
  end

  alias send send_data

  def receive_data(data)
    data = @buffer.extract(data)
    data.each do |line|
      Bot.log.info "#{self.class.name} #{@s[:name]}\n\t#{'<-'.cyan} #{line.chomp}"
      handle_message(parse_data(line))
    end
  rescue StandardError => e
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
      channel   = (data[2] == @s[:nick] ? matches[:sender] : data[2])
      internal_type = :client
    elsif data[1] =~ /^(JOIN|PART)$/
      type      = data[1].downcase.to_sym
      matches   = data[0].match(privm_regex)
      sender    = matches[:sender]
      real_name = matches[:real_name]
      hostname  = matches[:hostname]
      channel   = data[2].gsub(/^:/, '')
    elsif data[1] =~ /^\d+$/
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
      @adapter.on_connect(self)
    when :"433"
      nick = m.raw.split(' ')[3]
      register(nick + '_')
      EM.add_timer(@nick_reclaim_interval) { nick(@s[:nick]) } # Try to reclaim desired nick
    when :privmsg
      check_trigger(m)
    end

    @adapter.publish(m)
  end

  def check_trigger(m)
    if m.text =~ /^#{Bot::SHORT_TRIGGER}([^ ]*)/i || # !command
       m.text =~ /^#{@s[:nick]}: ([^ ]*)/i # BotNick: command
      trigger = Regexp.last_match[1]
      @adapter.trigger_plugin(trigger, m)
    end
  end

  def register(nick)
    nick(nick)
    user(nick, 0, ':Romani ite domum')
  end

  def keep_alive
    period_timer = EventMachine::PeriodicTimer.new(@ping_interval) do
      if @state == :connected
        send "PING #{Time.now.to_f}"
        @state = :waiting
        EM.add_timer(@timeout) do
          if @state == :waiting
            Bot.log.warn "Ping timeout (#{@timeout}s)"
            @state = :reconnecting
            period_timer.cancel
            close_connection
          end
        end
      else
        period_timer.cancel
      end
    end
  end

  def unbind
    if @state != :quitting && !($shutdown || $restart)
      Bot.log.warn "Connection closed: unexpected; reconnecting in #{@reconnect_delay} seconds..."
      EM.add_timer(@reconnect_delay) { @adapter.reconnect(@s[:name]) }
    end

    @state = :disconnected
  end
end
