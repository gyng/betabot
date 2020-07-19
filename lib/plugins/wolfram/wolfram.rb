class Bot::Plugin::Wolfram < Bot::Plugin
  def initialize(bot)
    # http://products.wolframalpha.com/api/
    # https://developer.wolframalpha.com/portal/apisignup.html
    @s = {
      trigger: {
        wolfram: [:call, 0, 'wolfram <query>. Querys Wolfram|Alpha.'],
        wa: [:call, 0, 'wa <query>. Querys Wolfram|Alpha.']
      },
      subscribe: false,
      api_key: '',
      max_depth: 2
    }
    super(bot)
  end

  def call(m)
    m.reply 'Wolfram API key has not been configured.' if @s[:api_key].empty?

    operation = proc {
      Timeout.timeout(30) do
        format_wolfram(wolfram(m.args.join(' ')))
      end
    }
    callback = proc { |result|
      m.reply result
    }
    errback = proc { |e| Bot.log.info "Woflram: Failed to get query #{e}" }
    EM.defer(operation, callback, errback)
  end

  def wolfram(search_term, depth = 1)
    return if depth > @s[:max_depth]

    search_term = CGI.escape(search_term)
    url = "http://api.wolframalpha.com/v2/query?appid=#{@s[:api_key]}&format=plaintext&input=\'#{search_term}\'"
    # rubocop:disable Security/Open
    raw = Nokogiri::XML(open(url))
    # rubocop:enable Security/Open
    pods = raw.search("//pod['title']")
    results = []

    pods.each do |pod|
      results.push(
        title: pod['title'].strip,
        text: pod.inner_text.strip.gsub("\n", ' ⋯ '.gray).strip.gsub(/  +/, ' ')
      )
    end

    if results.empty?
      related_examples = raw.search('//relatedexamples')

      if !related_examples.empty?
        related_examples = raw.search('//relatedexamples/relatedexample')
        search_term = related_examples[0]['input']
        results = wolfram(search_term, depth + 1)
      end
    end

    results
  end

  def format_wolfram(results)
    results.empty? ? 'Nothing found.' : "#{results[0][:text].bold}: #{results[1][:text]}"
  end
end
