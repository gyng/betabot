class Bot::Core::Message
  attr_accessor :adapter
  attr_accessor :hostname
  attr_accessor :internal_type # Server or client message, distinct from adapter's internal message :type
  attr_accessor :sender
  attr_accessor :text
  attr_accessor :time

  def initialize
    yield self if block_given?
  end

  # Base implementation, used for testing
  def args
    [text.split(' ')[1..-1]].flatten
  end

  def reply(*args)
  end
end
