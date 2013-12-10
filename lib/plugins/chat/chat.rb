class Bot::Plugin::Chat < Bot::Plugin
  def initialize(bot)
    @s = {
      trigger: { chat: [
        :call, 0,
        'chat [about <some thing> | stats | chip_p <p [0..1]> | ' +
        'learnoff | learnon | educate]. Chat with the bot.'
      ]},
      subscribe: true,
      brain_path: ['lib', 'plugins', 'chat', 'settings', 'brain.dat'],
      key_length: 2,
      chain_length: 2,
      max_sentence_length: 20, # Number of chains
      textbook: ['lib', 'plugins', 'chat', 'settings', 'textbook.txt'],
      learn_buffer_size: 10,
      chip_in_probability: 0.0015, # Approx. every 666.6
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
      m.reply "Brain size: #{@brain.size}"
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
      m.reply talk(m.args[1..(1 + @s[:key_length])].join(' '))
    else
      learn(m.text)
      m.reply talk
    end
  end

  def receive(m)
    if (Random.rand < @s[:chip_in_probability])
      if (m.type == :privmsg) # IRC only for now until I figure out message types
        topic = m.text.split(' ').first(@s[:key_length]).join(' ')
        m.reply talk(topic)
      end
    end

    if (@s[:learning])
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
end