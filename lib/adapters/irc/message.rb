class Bot::Adapter::Irc::Message < Bot::Core::Message
  attr_accessor :adapter
  attr_accessor :sender
  attr_accessor :real_name
  attr_accessor :hostname
  attr_accessor :type
  attr_accessor :channel
  attr_accessor :text
  attr_accessor :raw
  attr_accessor :time
  attr_accessor :origin

  def initialize
    yield self if block_given?
    @adapter = :irc
    @time = Time.now
  end

  def reply(text)
    @origin.send "PRIVMSG #{@channel} :#{text}"
  end

  def args
    # Extra space if called by name (!ping vs BotName: ping).
    # Assumes text is a String, wrap in array anyway if cannot split
    if /^#{Bot::SHORT_TRIGGER}([^ ]*)/i === @text
      [@text.split(' ')[1..-1]].flatten
    else
      [@text.split(' ')[2..-1]].flatten
    end
  end

  def mode
    args[0]
  end
end