class Bot::Adapter::Irc::Message < Bot::Core::Message
  attr_accessor :real_name, :hostname, :type, :channel, :raw, :origin

  def initialize
    super
    yield self if block_given?
    @adapter = :irc
    @time = Time.now
  end

  def reply(text)
    # RFC2812 Section 2.3 - Max of 512 characters (termination \r\n inclusive)
    text.to_s.each_line do |line|
      line_prefix = "PRIVMSG #{@channel} :"
      ellipsis = '…'
      joiner = ' '
      newline = '\r\n'
      # 512 - 'PRIVMSG #{@channel} :' - '\r\n'
      # max_segment_length = 510 - "PRIVMSG #{@channel} :".length - '...'.length
      max_segment_length_buffer = 30 # Play it safe
      max_segment_length = 512 - line_prefix.length - newline.length \
      - joiner.length - ellipsis.length - max_segment_length_buffer

      min_segment_length_buffer = 30
      min_segment_length = max_segment_length - min_segment_length_buffer

      chunks = chunk(line, min_segment_length, max_segment_length).to_a

      chunks.each do |line_segment|
        reply = "#{line_prefix}#{line_segment}"
        reply += '…' if line_segment != chunks.last && reply[-1] !~ /[[:punct:]]/
        @origin.send reply
      end
    end
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

  def chunk(input, min_length, max_length, &block)
    # @param input [String]
    # @param min_length [Numeric] how long the string should be before starting to look-ahead for chopping
    # @param max_length [Numeric] how long can the line chopping look-ahead to
    return to_enum(:chunk, input, min_length, max_length) unless block_given?

    output_current = ''
    blank_regex = /[[:blank:]]/
    blanks = input.scan(blank_regex)

    input.split(blank_regex).each_with_index do |x, i|
      blank = blanks[i] || ''

      if output_current.bytesize + x.bytesize < min_length
        output_current += x + blank
      elsif max_length < output_current.bytesize + x.bytesize
        parts = split_on_grapheme(output_current + x, max_length).to_a
        parts[0..-2].each(&block)
        output_current = parts[-1]
      else
        yield output_current.rstrip
        output_current = x + blank
      end
    end

    # NOTE: rstrip doesn't handle unicode blanks
    yield output_current.rstrip if output_current.size.positive?
  end

  def split_on_grapheme(input, max_length, &_block)
    return to_enum(:split_on_grapheme, input, max_length) unless block_given?

    output_current = ''
    input.each_grapheme_cluster do |g|
      if output_current.bytesize + g.bytesize < max_length
        output_current += g
      else
        yield output_current
        output_current = ''
      end
    end
    yield output_current if !output_current.empty?
  end
end
