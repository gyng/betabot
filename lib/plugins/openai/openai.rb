# rubocop:disable Layout/LineLength
# rubocop:disable Metrics/MethodLength

class Bot::Plugin::Openai < Bot::Plugin
  def initialize(bot)
    @s = {
      trigger: {
        ai: [:ai, 0, 'ai <prompt name> <prompt>. "ai list" lists prompts.'],
        ask: [:ask, 0, 'ask <your question>'],
        chatroom: [:chatroom, 0, 'Takes last 3 lines and continues the conversation. chatroom [personality=cute anime girl]']
      },
      subscribe: true,
      openai_api_key: 'OpenAPI API key here',
      openai_api_endpoint: 'https://api.openai.com/v1/engines/davinci/completions'
    }

    @chat_buf = {}

    super(bot)
  end

  def receive(m)
    return if m.text.nil?
    return unless (m.type == :privmsg) && !m.text.start_with?(Bot::SHORT_TRIGGER)

    @chat_buf[m.channel] = [] if @chat_buf[m.channel].nil?
    @chat_buf[m.channel].unshift({ user: m.sender, text: m.text })
    @chat_buf[m.channel] = @chat_buf[m.channel][0..3]
  end

  def default_args
    {
      prompt: ''.force_encoding('UTF-8'),
      temperature: 0.9,
      max_tokens: 100,
      top_p: 1,
      frequency_penalty: 0.0,
      presence_penalty: 0.6,
      best_of: 2,
      stop: ["\n"]
    }
  end

  def ai(m)
    args = get_args_for(m)

    m.reply(api_call(args).strip) if !args.nil?
  end

  def ask(m)
    # Here for convenience
    args = default_args
    args[:prompt] = "Q: #{m.args.join(' ')}\nA:"

    m.reply(api_call(args))
  end

  def get_args_for(m)
    args = default_args
    modes = [
      'ask <question>',
      'story <topic>',
      'plot <of title>',
      'chat <message>',
      'tldr <text>',
      'translate <text>',
      'emojify <text>',
      'code <purpose>',
      'wolfram <query>',
      'haiku <topic>',
      'singlish <english>'
    ]

    text = m.args[1..-1].join(' ').force_encoding('UTF-8')

    case m.args
    in ['list', *input]
      m.reply modes.join(', ')
      return nil
    in ['help', *input]
      m.reply modes.join(', ')
      return nil
    in ['ask', *input]
      args[:prompt] = "Q: #{text}\nA:"
    in ['story', *input]
      args[:prompt] = "Topic: Breakfast\n" \
      'Two-Sentence Horror Story: He always stops crying when I pour the milk on his cereal. '\
      "I just have to remember not to let him see his face on the carton.\n" \
      "###\n"\
      "Topic: #{text}" \
      'Two-Sentence Horror Story:'
    in ['plot', *input]
      args[:prompt] = "Title: Your Lie in April\n" \
      "Japanese Title: 四月は君の嘘\n"\
      "Genres: Musical, romantic drama\n"\
      "Plot: Piano prodigy Kōsei Arima dominates various music competitions and becomes famous among child musicians. When his mother Saki dies suddenly, he has a mental breakdown while performing at a piano recital; this results in him no longer being able to hear the sound of his piano even though his hearing is otherwise perfectly fine.\n\n" \
      "Title: Neon Genesis Evangelion\n" \
      "Japanese Title: 新世紀エヴァンゲリオン\n"\
      "Genres: Apocalyptic, Mecha, Psychological drama\n" \
      "Plot: In 2015, fifteen years after a global cataclysm known as the Second Impact, teenager Shinji Ikari is summoned to the futuristic city of Tokyo-3 by his estranged father Gendo Ikari, director of the special paramilitary force Nerv. Shinji witnesses United Nations forces battling an Angel, one of a race of giant monstrous beings whose awakening was foretold by the Dead Sea Scrolls.\n\n" \
      "Title: Non Non Biyori\n"\
      "Japanese Title: のんのんびより\n"\
      "Genres: 	Comedy, slice of life\n" \
      "Plot: The story takes place in the countryside small town village of Asahigaoka, a place lacking many of the conveniences that people from the city are accustomed to. The nearest stores are a few miles away and one of the local schools consists of only five students, each of whom is in a different grade of elementary or middle school. Hotaru Ichijo, a fifth grader from Tokyo, transfers into Asahigaoka Branch School and adjusts to countryside life with her new friends.\n\n" \
      "Title: #{text}\n"\
      'Japanese Title:'
      args[:stop] = ['Title:']
    in ['chat', *input]
      args[:prompt] = "'#{text}'. A reply to that is:"
    in ['tldr', *input]
      args[:prompt] = "#{text}\n\ntl;dr:"
    in ['translate', *input]
      args[:prompt] = "Input: 悪事はたしかに千里を走るらしい。\n" \
        "English: Bad news certainly travels swiftly.\n"\
        "Input: Was ist deiner Lieblingssupermarkt?\n" \
        "English: What is your favorite grocery store?\n" \
        "Input: #{text}\n" \
        'English:'
    in ['emojify', *input]
      args[:prompt] = "Usage: General pleasure and good cheer or humor\n" \
      "Emoji: 😀, 🤗, 😺\n" \
      "Usage: Metaphorical expressions related to fire, including the slang hot (“attractive”) and lit (“excellent”):\n" \
      "Emoji: 🔥\n" \
      "Usage: Making money, loving wealth, being or feeling rich, and concepts of success and excellence\n" \
      "Emoji: 🤑, 💰\n" \
      "Usage: #{input.join(' ')}\n" \
      'Emoji:'
      args[:stop] = ['Emoji:', 'Usage:', "\n"]
    in ['code', *input]
      args[:prompt] = "# The following one-liner shell script will #{text}\n$"
      args[:stop] = ['#']
    in ['wolfram', *input]
      args[:prompt] = "Input: solve x^2 + 4x + 6 = 0\n" \
"Output: x = -2 + i sqrt(2)\n" \
"Input: convert 1/6 to percent\n" \
"Output: 16.67%\n" \
"Input: H2SO4\n" \
"Output: sulfuric acid\n" \
"Input: #{text}\n" \
'Output:'
    in ['haiku', *input]
      args[:prompt] = "Topic: old pond\n"\
      "Haiku:古池や蛙飛び込む水の音 = old pond / frog leaps in / water's sound\n"\
      "Topic: drizzle\n"\
      "Haiku: 初しぐれ猿も小蓑をほしげ也 = the first cold shower / even the monkey seems to want / a little coat of straw\n"\
      "Topic: #{text}\n"\
      'Haiku:'
      args[:stop] = ["\n", 'Topic:']
    in ['singlish', *input]
   args[:prompt] = "English: This isn't good.\n"\
"Singlish: No good lah.\n"\
"English: You can't just go like that.\n"\
"Singlish: Cannot anyhow go like dat oe leh.\n"\
"English: Why didn't you show up?\n"\
"Singlish: How come never show up\n"\
"English: I play badminton every weekend because I like it.\n"\
"Singlish: I like badminton, dat's why I every weekend go pay.\n"\
"English: You don't need to bring a camera tomorrow\n"\
"Singlish: Tomorrow don't need bring camera.\n"\
"English: Does your computer have a virus?\n"\
"Singlish: Your computer got virus or not?\n"\
"English: I am very naughty.\n"\
"Singlish: I damn naughty.\n"\
"English: Oh dear, I cannot wait any longer. I must leave immediately.\n"\
"Singlish: Aiyah, cannot wait any more, must go already.\n"\
"English: Is this possible?\n"\
"Singlish: Can or not?\n"\
"English: #{text}\n"\
'Singlish:'
    else
      args[:prompt] = text
    end

    args
  end

  def chatroom(m)
    personality = m.args.join(' ') || 'a cute anime girl'
    buf = last_n_chat(m, 3)
    args = default_args
    args[:prompt] = "The following is a conversation in an online chatroom.\n" \
      "I am #{personality} and will continue the conversation.\n\n" \
      "Me: Hello\n" \
      "#{buf}"
    m.reply api_call(args)
  end

  private

  # n up to 3
  def last_n_chat(m, n)
    curbuf = @chat_buf[m.channel] || []

    buf = curbuf[0..n].reverse.map do |msg|
      "#{msg[:user]}: #{msg[:text]}"
    end.join("\n")

    buf
  end

  def last_n(m, n)
    curbuf = @chat_buf[m.channel] || []
    buf = curbuf[0..n].reverse
    buf
  end

  def api_call(args)
    url = @s[:openai_api_endpoint]
    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{@s[:openai_api_key]}"
    }
    # body = {
    #   prompt: prompt.force_encoding('UTF-8'),
    #   temperature: 0.9,
    #   max_tokens: max_tokens,
    #   top_p: 1,
    #   frequency_penalty: 0.0,
    #   presence_penalty: 0.6,
    #   stop: stop || ["\n"]
    # }.to_json
    body = args
    body[:prompt] = body[:prompt].force_encoding('UTF-8')
    body = body.to_json

    Bot.log.info "#{self.class.name} - Headers: #{headers}"
    Bot.log.info "#{self.class.name} - Prompt: #{args[:prompt]}"

    begin
      res = JSON.parse(RestClient.post(url, body, headers), symbolize_names: true)
    rescue StandardError => e
      puts e.response
    end

    Bot.log.info "#{self.class.name} - Completing: #{res}"

    completion = res[:choices][0][:text]
    completion.blank? ? '[Empty response received from server]' : completion
  end
end

# rubocop:enable Metrics/MethodLength
# rubocop:enable Layout/LineLength
