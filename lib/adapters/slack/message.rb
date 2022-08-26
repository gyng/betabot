class Bot::Adapter::Slack::Message < Bot::Core::Message
  attr_accessor :channel, :client, :data, :hostname, :origin, :text, :user # Used for auth

  def initialize
    super
    yield self if block_given?
    @adapter = :slack
    @time = Time.now
  end

  def reply(text)
    Bot.log.info "#{self.class.name} #{@channel}\n\t#{'->'.green} #{text}"
    @client.typing(channel: @channel)
    @client.message(channel: @channel, text:)
  end

  def args
    # Extra space if called by name (!ping vs BotName: ping).
    # Assumes text is a String, wrap in array anyway if cannot split
    if @text =~ /^#{Bot::SHORT_TRIGGER}([^ ]*)/i
      [@text.split(' ')[1..]].flatten
    else
      [@text.split(' ')[2..]].flatten
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
