class Bot::Adapter::Slack::Message < Bot::Core::Message
  attr_accessor :channel
  attr_accessor :client
  attr_accessor :data
  attr_accessor :hostname # Used for auth
  attr_accessor :origin
  attr_accessor :text
  attr_accessor :user

  def initialize
    yield self if block_given?
    @adapter = :slack
    @time = Time.now
  end

  def reply(text)
    Bot.log.info "#{self.class.name} #{@channel}\n\t#{'->'.green} #{text}"
    @client.typing(channel: @channel)
    @client.message(channel: @channel, text: text)
  end

  def args
    # Extra space if called by name (!ping vs BotName: ping).
    # Assumes text is a String, wrap in array anyway if cannot split
    if @text =~ /^#{Bot::SHORT_TRIGGER}([^ ]*)/i
      [@text.split(' ')[1..-1]].flatten
    else
      [@text.split(' ')[2..-1]].flatten
    end
  end

  def mode
    args[0]
  end

  private

  def chunk(str, length)
    str.scan(/\S.{0,#{length - 1}}(?!\S)/)
  end
end
