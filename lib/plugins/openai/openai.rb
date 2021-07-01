class Bot::Plugin::Openai < Bot::Plugin
  def initialize(bot)
    @s = {
      trigger: {
        ai: [:prompt, 0, 'ai <OpenAI prompt>'],
        ask: [:ask, 0, 'ask <your question>'],
        chat: [:chat, 0, 'chat <message>'],
        chatroom: [:chatroom, 0, 'chatroom [personality=cute anime girl]'],
        choose: [:choose, 0, 'choose <item list>'],
        quip: [:quip, 0, 'quip [personality=sensible]'],
        story: [:story, 0, 'story <topic=last chat message>'],
        tldr: [:tldr, 0, 'tldr']
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

  def prompt(m)
    m.reply api_call(m.args.join(' '))
  end

  def choose(m)
    text = m.args.join(' ')
    prompt = "Q: choose an item from this list and tell me why you picked it: #{text}\nA:"
    m.reply api_call(prompt, 64, ["\n", 'Q:'])
  end

  def chat(m)
    personality = 'great'
    text = m.args.join(' ')
    prompt = "'#{text}'. A #{personality} reply to that is:"
    m.reply api_call(prompt, 64)
  end

  def chatroom(m)
    personality = m.args.join(' ') || 'a cute anime girl'
    buf = last_n_chat(m, 3)
    prompt = "The following is a conversation in an online chatroom.\n" \
      "I am #{personality} and will continue the conversation.\n\n" \
      "Me: Hello\n" \
      "#{buf}"
    m.reply api_call(prompt, 64, ['EOF'])
  end

  def tldr(m)
    buf = last_n_chat(m, 1)
    prompt = "#{buf}\n\ntl;dr:"
    m.reply api_call(prompt, 32)
  end

  def quip(m)
    personality = m.args.join(' ') || 'sensible'
    text = last_n_chat(m, 1)

    prompt = "'#{text}' A #{personality} response to that statement is:"
    m.reply api_call(prompt, 128)
  end

  def ask(m)
    text = m.args.join(' ')
    prompt = "Q: #{text}\nA:"
    m.reply api_call(prompt, 128)
  end

  def story(m)
    topic = m.args.join(' ').blank? ? last_n(m, 1) : m.args.join(' ')
    topic ||= m.sender

    prompt = "Topic: Breakfast\n" \
    'Two-Sentence Horror Story: He always stops crying when I pour the milk on his cereal. '\
    "I just have to remember not to let him see his face on the carton.\n" \
    "###\n"\
    "Topic: #{topic}" \
    'Two-Sentence Horror Story:'

    m.reply api_call(prompt, 128)
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

  def api_call(prompt, max_tokens = 64, stop = ["\n"])
    url = @s[:openai_api_endpoint]
    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{@s[:openai_api_key]}"
    }
    body = {
      prompt: prompt,
      temperature: 0.9,
      max_tokens: max_tokens,
      top_p: 1,
      frequency_penalty: 0.0,
      presence_penalty: 0.6,
      stop: stop || ["\n"]
    }.to_json

    Bot.log.info "#{self.class.name} - Prompt: #{prompt}"

    begin
      res = JSON.parse(RestClient.post(url, body, headers), symbolize_names: true)
    rescue StandardError => e
      puts e.response
    end

    Bot.log.info "#{self.class.name} - Completing: #{res}"

    completion = res[:choices][0][:text]
    completion
  end
end
