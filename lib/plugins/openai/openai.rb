# rubocop:disable Layout/LineLength
# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/ClassLength

class Bot::Plugin::Openai < Bot::Plugin
  def initialize(bot)
    @s = {
      trigger: {
        ai: [:ai, 0, 'ai <prompt name> <prompt>. "ai list" for available prompt names.'],
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
      frequency_penalty: 0.0,
      presence_penalty: 0.6,
      best_of: 1,
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
      'singlish <english>',
      'mtg <name>',
      'jira <product>',
      'changelog [topic=None]'
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
      args[:prompt] = "Title: Neon Genesis Evangelion\n" \
      "Japanese Title: 新世紀エヴァンゲリオン | Genres: Apocalyptic, Mecha, Psychological drama\n"\
      "Plot: In 2015, fifteen years after a global cataclysm known as the Second Impact, teenager Shinji Ikari is summoned to the futuristic city of Tokyo-3 by his estranged father Gendo Ikari, director of the special paramilitary force Nerv. Shinji witnesses United Nations forces battling an Angel, one of a race of giant monstrous beings whose awakening was foretold by the Dead Sea Scrolls.\n" \
      "\nTitle: #{text}\n"\
      'Japanese Title:'
      args[:stop] = ['Title:']
      args[:temperature] = 0.95
      args[:max_tokens] = 128
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
"English: I am very naughty.\n"\
"Singlish: I damn naughty.\n"\
"English: Oh dear, I cannot wait any longer. I must leave immediately.\n"\
"Singlish: Aiyah, cannot wait any more, must go already.\n"\
"English: Is this possible?\n"\
"Singlish: Can or not?\n"\
"English: #{text}\n"\
'Singlish:'
    in ['mtg', *input]
      args[:prompt] = "Name: {Moonglove Winnower}\n" \
      "{3}{B} [elf facing left] 2/3 Creature — Elf Rogue\n" \
      "Deathtouch (Any amount of damage this deals to a creature is enough to destroy it.)\n" \
      "Winnowers live to eliminate eyeblights, creatures the elves deem too ugly to exist.\n" \
      "###\n" \
      "Name: {Arrow Storm}\n" \
      "{3}{R}{R} [horse archers firing arrows] Sorcery\n" \
      "Arrow Storm deals 4 damage to any target.\n" \
      "Raid — If you attacked this turn, instead Arrow Storm deals 5 damage to that permanent or player and the damage can't be prevented.\n" \
      "First the thunder, then the rain.\n" \
      "###\n" \
      "Name: {#{text}}"
      args[:stop] = ["\n\n", '###']
      args[:top_p] = 1
      in ['jira', *input]
        # https://twitter.com/shituserstory
        args[:prompt] = "For our app\n" \
        "[JIRA-52] As a user, I want to be locked out of my current app version and forced to update, so that I can be protected from the old colour scheme\n" \
        "\n"\
        "For GMail\n"\
        "[GMAL-5931] As a user, I want to have two small unlabelled oblong-shaped icons next to each other, representing commonly used interactions, the primary contrast being a 90° rotation, so that there is no ambiguity between choosing to attach a file or insert a link\n"\
        "\n"\
        "For Excel\n"\
        "[EXC-1769] As a user, I want to have fractions automatically converted to dates so that I can spend 01-Oct of my day manually changing them back\n"\
        "\n"\
        "For Twitter\n"\
        "[TWAT-86]
         As a user, I want to click on the ‘show more replies’ bar, so that when it disappears, revealing absolutely nothing, I can be disappointed I didn’t get to see a shit opinion from a dickhead\n"\
        "\n"\
        "For #{text || 'our app'}\n"
        args[:stop] = ["\n\n"]
      in ['changelog', *input]
        # https://twitter.com/thestrangelog?lang=en
        topic = text || '*'
        args[:prompt] = "*: [FIX] Grandma now pays less if you have a prison tattoo\n"\
        "*: [FIX] Colonist with a sick thought won't meditate at all.\n"\
        "*: [CHANGE] Lowered wolf procreation slightly\n"\
        "sacrifice: [FIX] No longer possible to sacrifice the same person to Satan multiple times\n"\
        "goose: [FEAT] Goose simulator added. Geese will now fly between lakes and swim around acting like geese.\n"\
        "friends: [FIX] you have no friends\n"\
        "#{topic}:"
        args[:stop] = ["\n"]
      in ['sc2', *input]
        args[:prompt] = "Build name: 4 Gate All-in\n"\
        '14 Pylon, '\
        '15 Gateway, '\
        '16 Assimilator, '\
        '18 Pylon'\
        "---\n"\
        "Build name: 12 pool\n"\
        '12 Spawning Pool, '\
        '14 Overlord, '\
        '14 Zergling x3, '\
        '17 Zergling'\
        "---\n"\
        "Build name: 3 rax proxy reaper\n"\
        '13 Supply Depot, '\
        '13 Refinery, '\
        '13 Barracks, '\
        '13 Barracks, '\
        '13 Barracks, '\
        '13 Reaper, '\
        "---\n"\
        "Build name: #{input}"
        args[:stop] = 'Build name'
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
    args[:stop] = nil
    args[:max_tokens] = 48
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

    completion = res && res[:choices] && res[:choices][0] && res[:choices][0][:text]
    completion.blank? ? '[Empty response received from server]' : completion
  end
end

# rubocop:enable Metrics/ClassLength
# rubocop:enable Metrics/MethodLength
# rubocop:enable Layout/LineLength
