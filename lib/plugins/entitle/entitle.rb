class Bot::Plugin::Entitle < Bot::Plugin
  require 'nokogiri'
  require 'open-uri'

  def initialize(bot)
    @s = {
      trigger: { entitle: [
        :call, 0,
        'entitle list, entitle add <filter>, entitle delete <filter>. ' \
        'Filters are regular expressions. Using these filters ' \
        'Entitle looks for uninformative URLs and blurts their titles out.'
      ] },
      subscribe: true,
      timeout: 10,
      filters: [
        'http.*?google\.com\S*',
        'http.+?=.\S+',
        'http.+\/\d+\/?[^\.]+$',
        'http.*?youtu\.be.\S+'
      ]
    }
    super(bot)
  end

  def call(m = nil)
    case m.args[0]
    when 'list'
      m.reply(@s[:filters].join(', '))
    when 'add'
      if @bot.auth(4, m)
        @s[:filters].push(m.args[1])
        save_settings
        m.reply('Filter added.')
      end
    when 'delete'
      if @bot.auth(4, m)
        @s[:filters].delete(m.args[1])
        save_settings
        m.reply('Filter deleted.')
      end
    else
      check_filter(m)
    end
  end

  def receive(m)
    check_filter(m)
  end

  def check_filter(m)
    line = String.new(m.text)

    @s[:filters].each do |regex|
      results = line.scan(Regexp.new(regex))

      next if results.empty?

      results.each do |result|
        Thread.new do
          timeout(@s[:timeout]) do
            title = get_title(result)
            m.reply(title) if !title.nil?
          end
        end

        # Prevent double-matching
        line.gsub!(result, '')
      end
    end
  end

  def get_title(url)
    Bot.log.info("Entitle: getting title of #{url}")
    # Storing into local var `html` bypasses bad unicode handling by Nokogiri
    html = open(url, allow_redirections: :all)
    doc = Nokogiri::HTML(html.read)
    doc.encoding = 'utf-8'
    doc.at_css('title').text.gsub(/ *\n */, ' ').strip
  end
end
