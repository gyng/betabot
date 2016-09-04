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
  attr_accessor :internal_type

  def initialize
    yield self if block_given?
    @adapter = :irc
    @time = Time.now
  end

  def reply(text)
    # RFC2812 Section 2.3 - Max of 512 characters (termination \r\n inclusive)
    text.to_s.each_line do |line|
      # 512 - 'PRIVMSG #{@channel} :' - '\r\n'
      # max_segment_length = 510 - "PRIVMSG #{@channel} :".length - '...'.length
      max_segment_length = 400 # Play it safe for non-compliant servers
      chunks = chunk(line, max_segment_length)

      chunks.each do |line_segment|
        reply = "PRIVMSG #{@channel} :#{line_segment}"
        reply += '...' if line_segment != chunks.last && !(reply[-1] =~ /[[:punct:]]/)
        @origin.send reply
      end
    end
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
