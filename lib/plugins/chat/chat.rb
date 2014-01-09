class Bot::Plugin::Chat < Bot::Plugin
  def initialize(bot)
    @s = {
      trigger: {
        chat: [
          :call, 0,
          'chat [about <some thing> | stats | chip_p <p [0..1]> | ' +
          'learnoff | learnon | educate]. Chat with the bot.'],
        haiku: [
          :call_haiku, 0,
          'haiku [topic]. Makes a bad haiku.'
        ]
      },
      subscribe: true,
      brain_path: ['lib', 'plugins', 'chat', 'settings', 'brain.dat'],
      key_length: 2,
      chain_length: 2,
      max_sentence_length: 20, # Number of chains
      textbook: ['lib', 'plugins', 'chat', 'settings', 'textbook.txt'],
      learn_buffer_size: 10,
      chip_in_probability: 0.001,
      learning: true
    }
    super(bot)

    load_brain
    @uncommited_learns = 0
  end

  def call(m)
    case m.mode
    when 'educate'
      if auth(4, m)
        educate(File.read(File.join(*@s[:textbook])))
        m.reply 'Bot is now educated.'
      end
    when 'stats'
      m.reply "Brain size: #{@brain.size} key values"
    when 'chip_p'
      if auth(4, m)
        if !m.args[1].nil?
          @s[:chip_in_probability] = m.args[1].to_f
          save_settings
        end
        m.reply "Chipping in p = #{@s[:chip_in_probability]}"
      end
    when 'learnoff'
      if auth(4, m)
        @s[:learning] = false
        save_settings
        m.reply "Learning: #{@s[:learning]}"
      end
    when 'learnon'
      if auth(4, m)
        @s[:learning] = true
        save_settings
        m.reply "Learning: #{@s[:learning]}"
      end
    when 'about'
      if m.args.size-1 < @s[:key_length]
        # If shorter than key length we search the keys for a matching topic
        seed = @brain.keys.find_all { |k| /#{(m.args[1..-1].sample)}/ =~ k }.sample
      else
        # Assume the user knows the exact phrase
        seed = m.args[1..(1 + @s[:key_length])].join(' ')
      end
      m.reply talk(seed)
    when 'haiku'
      call_haiku(m)
    else
      learn(m.text)
      m.reply talk
    end
  end

  def call_haiku(m)
    if m.args.nil? || m.args.empty?
      m.reply haiku
    else
      seed = @brain.keys.find_all { |k| /#{(m.args.sample)}/ =~ k }.sample
      m.reply haiku(seed)
    end
  end

  def receive(m)
    if (Random.rand < @s[:chip_in_probability])
      if (m.type == :privmsg) # IRC only for now until I figure out message types
        topic = m.text.split(' ').first(@s[:key_length]).join(' ')
        m.reply talk(topic)
      end
    end

    if (@s[:learning] && m.internal_type == :client)
      learn(m.text)
      save_brain if @uncommited_learns > @s[:learn_buffer_size]
    end
  end

  def save_brain
    File.open(File.join(*@s[:brain_path]), 'wb') { |f| Marshal.dump(@brain, f) }
    @uncommited_learns = 0
  end

  def load_brain
    brain_path = File.join(*@s[:brain_path])

    if !File.directory?(File.dirname(brain_path))
      FileUtils.mkdir_p(File.dirname(brain_path))
    end

    if File.exists?(brain_path)
      @brain = File.open(brain_path) { |f| Marshal.load(f) }
    else
      @brain = {}
    end
  end

  def educate(textbook)
    textbook.each_line { |line| learn(line) }
    save_brain
  end

  def learn(line)
    # key_length 2 and chain_length 1
    # 'my dog'     => ['went', 'died']
    # 'dog went'   => ['to']
    # 'went to'    => ['the']
    # 'to the'     => ['market']
    # 'the market' => ["\n"]
    # 'dog died'   => ["\n"]

    tokens = line.split(' ').push("\n")
    return if tokens.nil?

    tokens.each_cons(@s[:key_length] + @s[:chain_length]) do |token|
      key = token.first(@s[:key_length]).join(' ')
      @brain[key] = [] unless @brain.has_key?(key)
      @brain[key].push(token.last(@s[:chain_length]).join(' '))
    end

    @uncommited_learns += 1
  end

  def talk(seed=nil)
    seed = @brain.keys.sample if seed.nil?
    sentence = seed.split(' ')

    while sentence.length < @s[:max_sentence_length]
      break if seed.nil? || @brain[seed].nil?
      append = @brain[seed].sample
      sentence.concat([append.split(' ')].flatten)
      seed = sentence.last(@s[:key_length]).join(' ')
    end

    sentence.join(' ')
  end

  def haiku(seed=nil)
    seed = @brain.keys.sample if seed.nil?
    line = seed.split(' ') # Start off with seed
    lines = []
    attempts = 0
    syllables = [5, 7, 5]

    0.upto(2) do |i|
      while count_line_syllables(line) != syllables[i] && ((attempts += 1) < 200) do
        seed = @brain.keys.sample if seed.nil? || @brain[seed].nil?
        append = @brain[seed].sample
        line.concat([append.split(' ')].flatten)
        line.shift(@s[:chain_length]) if count_line_syllables(line) > syllables[i]

        if attempts % 50 == 0
          seed = @brain.keys.sample
        else
          seed = line.last(@s[:key_length]).join(' ')
        end
      end

      attempts = 0
      lines.push(line.join(' '))
      line = []
    end

    # lines = lines.map { |l| "(#{count_line_syllables(l.split(' '))}) " + l }
    lines.join("\n")
  end

  def count_line_syllables(line)
    line.inject(0) { |acc, e| acc + count_syllables(e) }
  end

  # http://stackoverflow.com/questions/1271918/ruby-count-syllables/1272072#1272072
  def count_syllables(str)
    word = String.new(str.to_s)
    word.downcase!
    return 1 if word.length <= 3
    word.sub!(/(?:[^laeiouy]es|ed|[^laeiouy]e)$/, '')
    word.sub!(/^y/, '')
    word.scan(/[aeiouy]{1,2}/).size
  end
end