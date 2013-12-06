class Bot::Adapter::Irc::Message
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
    @time = Time.now
  end
end