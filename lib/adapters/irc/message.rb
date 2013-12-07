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
    @text.split(' ')[2..-1] if @text.is_a?(String)
  end

  def trigger
    @text.split(' ')[1]
  end
end