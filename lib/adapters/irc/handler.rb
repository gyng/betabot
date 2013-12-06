class Bot::Adapter::Irc::Handler < EM::Connection
  def initialize(ssl)
    @ssl = ssl
    @registered = false
    @buffer = ''
  end

  def connection_completed
    start_tls if @ssl
    register
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

  def handle_message(message)
    case message.type
    when :ping
      send "PONG #{message.sender} #{message.text}"
    when :"001"
      @registered = true
      send("JOIN #fauxbot")
    end
  end

  def register
    send "NICK WaruiBot"
    send "USER WaruiBot 0 * :Watashi wa kawaii desu."
  end
end