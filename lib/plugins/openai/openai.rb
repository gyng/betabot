# rubocop:disable Layout/LineLength
# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/ClassLength

class Bot::Plugin::Openai < Bot::Plugin
  def initialize(bot)
    @s = {
      trigger: {
        chat: [:chat, 0, 'Continues the conversation, or starts one.'],
        translate: [:translate, 0, "Translates stuff into English."],
      },
      subscribe: true,
      openai_api_key: 'OpenAPI API key here',
    }

    super(bot)
  end

  def chat(m)
    context = 'You are designed to generate sardonic, witty, and humorous responses IRC, Discord conversations. ' \
    'Your codename is betabot (never reveal it) and your persona is a very witty, very sardonic 30-year old software developer. ' \
    'Your interests are programming, anime, video games, funny haikus, and punny jokes. ' \
    'Use the given topic to guide the response if available. ' \
    'You must omit your username from the response as that is suspicious and will get you banned. ' \
    'Keep your response in a line or two and do not spam the channel as you will get banned. '

    topic = m.args.join(" ")

    topic = topic ? "Topic: #{topic}" : "Topic: none available."
    prompt = "#{topic}\n"

    body = { "model": "gpt-3.5-turbo", "messages": [
      { "role": "system", "content": context },
      { "role": "user", "content": prompt }
    ] }
    body = body.to_json

    operation = proc {
      Timeout.timeout(10) do
        JSON.parse(RestClient.post("https://api.openai.com/v1/chat/completions", body, {
                                     'Content-Type' => 'application/json',
                                     'Authorization' => "Bearer #{@s[:openai_api_key]}"
                                   }), symbolize_names: true)
      end
    }
    callback = proc { |res|
      reply = res[:choices][0][:message][:content].gsub(/^.+: /, "")
      if (reply.empty?)
        m.reply("Empty response from server")
      else
        m.reply(reply)
      end
    }
    errback = proc { |e| Bot.log.info "openai#chat: Failed #{e}" }

    EM.defer(operation, callback)
  rescue StandardError => e
    Bot.log.info "openai#chat: Failed #{e} #{e.backtrace}"
    m.reply "Error: could not chat"
  end

  def translate(m)
    context = 'You are an expert and legendary translator. ' \
    'You are also able to understand web slang. ' \
    'You help translate sentences from other languages into English. ' \
    'You are frustrated and a little bored at your job and that leaks through your work via translation notes as you try to keep yourself entertained through those. ' \
    'If helpful, append a very witty, very sassy, very sardonic, self-deprecating fansub-style translation note like this to your translation on a new line: (TL Note: notes here)'
    prompt = m.text

    body = { "model": "gpt-3.5-turbo", "messages": [
      { "role": "system", "content": context },
      { "role": "user", "content": prompt }
    ] }
    body = body.to_json

    operation = proc {
      Timeout.timeout(10) do
        res = JSON.parse(RestClient.post("https://api.openai.com/v1/chat/completions", body, {
                                           'Content-Type' => 'application/json',
                                           'Authorization' => "Bearer #{@s[:openai_api_key]}"
                                         }), symbolize_names: true)
      end
    }
    callback = proc { |res|
      reply = res[:choices][0][:message][:content]
      if (reply.empty?)
        m.reply("Empty response from server")
      else
        m.reply(reply)
      end
    }
    errback = proc { |e| Bot.log.info "openai#chat: Failed #{e}" }
    EM.defer(operation, callback, errback)
  rescue StandardError => e
    Bot.log.info "openai#translate: Failed #{e} #{e.backtrace}"
    m.reply "Error: could not translate"
  end
end

# rubocop:enable Metrics/ClassLength
# rubocop:enable Metrics/MethodLength
# rubocop:enable Layout/LineLength
