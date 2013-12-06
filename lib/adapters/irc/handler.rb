class Bot::Adapter::Irc::Handler < EM::Connection
  def initialize(adapter, s=Hash.new(false))
    @adapter = adapter
    @s = s
    @registered = false
    @ping_state = :inactive
    @buffer = ''
  end

  def connection_completed
    start_tls if @s[:ssl]
    register
    start_ping_timer(120, 30)
  end

  def send_data(data)
    Bot.log.info "#{self.class.name}\n\t#{'->'.green} #{data}"
    super data + "\n"
  end

  alias_method :send, :send_data

  def receive_data(data)
    @buffer << data

    while line = @buffer.slice!(/(.+)\r?\n/)
      Bot.log.info "#{self.class.name}\n\t#{'<-'.cyan} #{line.chomp}"
      handle_message(parse_data(line))
    end
  end

  def parse_data(data)
    sender, real_name, hostname, type, channel = nil
    privm_regex = /^:(?<sender>.+)!(?<real_name>.+)@(?<hostname>.+)/
    origin      = self
    raw         = data
    text        = data.split(' :').last.chomp
    data        = data.split(' ')

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
    end
  end

  def handle_message(m)
    case m.type
    when :ping
      send "PONG #{m.sender} #{m.text}"
    when :pong
      @ping_state = :received
      @adapter.latency = (Time.now.to_f - m.text.to_f) * 1000
    when :"001"
      @registered = true
      send("JOIN #fauxbot")
    when :privmsg
      check_trigger(m)
    end
  end

  def check_trigger(m)
    # if m.text.match(/^#{s[:nick]}:.*/)
    tokens = m.text.split(' ')

    if tokens[0] == @s[:nick] + ':'
      trigger = tokens[1]
      @adapter.trigger_plugin(trigger, m)
    end
  end

  def register
    send "NICK WaruiBot"
    send "USER WaruiBot 0 * :Watashi wa kawaii desu."
  end

  def quit(text='')
    send "QUIT #{text}"
  rescue
  end

  def start_ping_timer(period, timeout)
    EventMachine::PeriodicTimer.new(period) do
      send "PING #{Time.now.to_f}"
      @ping_state = :wait
      EventMachine::Timer.new(timeout) do
        if @ping_state == :wait
          Bot.log.warn "Ping timeout: PONG not received from server within #{timeout}s"
          quit
          @adapter.reconnect
        end
      end
    end
  end
end