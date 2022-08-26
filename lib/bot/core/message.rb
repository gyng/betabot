class Bot::Core::Message
  # Server or client message, distinct from adapter's internal message :type
  attr_accessor :adapter, :hostname, :internal_type, :sender, :text, :time

  def initialize
    yield self if block_given?
  end

  # Base implementation, used for testing
  def args
    [text.split(' ')[1..]].flatten
  end

  def reply(*args); end
end
