class Bot::Core::Message
  attr_accessor :sender
  attr_accessor :hostname
  attr_accessor :internal_type # Server or client message, distinct from adapter's internal message :type

  def reply
  end
end