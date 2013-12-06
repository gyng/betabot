class Bot::Adapter::Irc::Handler < EM::Connection
  def initialize(adapter, ssl=false)
    @adapter = adapter
    @ssl = ssl
    @registered = false
    @ping_state = :inactive
    @buffer = ''
  end

  def connection_completed
    start_tls if @ssl
    register
    start_ping_timer(120, 30)
  end

  def send_data(data)
    puts 'x'
    Bot.log.info "#{self.class.name}\n\t#{'->'.magenta} #{data}"
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
    # register if !@registered

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
    end
  end

  def register
    send "NICK WaruiBot"
    send "USER WaruiBot 0 * :Watashi wa kawaii desu."
  end

  def start_ping_timer(period, timeout)
    EventMachine::PeriodicTimer.new(period) do
      send "PING #{Time.now.to_f}"
      @ping_state = :wait
      EventMachine::Timer.new(timeout) do
        Bot.log.warn 'PONG not received from server' if @ping_state == :wait
      end
    end
  end
end