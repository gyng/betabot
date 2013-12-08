class Bot::Plugin::Entitle < Bot::Plugin
  require 'nokogiri'
  require 'open-uri'

  def initialize(bot)
    @s = {
      trigger: { entitle: [:call, 0] },
      subscribe: true,
      help: 'Entitle looks for uninformative URLs and blurts their titles out.',
      timeout: 10,
      filters: [
        "http.*?youtu\\(\\.be|be\\.com\\)\\S*",
        "http.*?google\\.com\\S*",
        "http.+?\\?.+?=.[^\\s]+"
      ]
    }
    super(bot)
  end

  def call(m=nil)
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

      unless results.empty?
        results.each do |result|
          Thread.new do
            timeout(@s[:timeout]) do
              title = get_title(result)
              m.reply(title) unless title.nil?
            end
          end

          # Prevent double-matching
          line.gsub!(result, '')
        end
      end
    end
  end

  def get_title(url)
    Bot.log.info("Entitle: getting title of #{url}")
    html = open(url) # Bypass bad unicode handling by Nokogiri
    doc = Nokogiri::HTML(html.read)
    doc.encoding = 'utf-8'
    doc.at_css('title').text.gsub(/ *\n */, " ").lstrip.rstrip
  end
end