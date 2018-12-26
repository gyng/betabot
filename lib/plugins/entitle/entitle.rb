class Bot::Plugin::Entitle < Bot::Plugin
  require 'nokogiri'
  require 'open-uri'
  require 'timeout'

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
    return if m.text.nil?

    tokens = String.new(m.text).split(' ').uniq
    titles = []

    @s[:filters].each do |regex_s|
      regex = Regexp.new(regex_s)

      tokens.each do |t|
        next if regex.match(t).nil?

        operation = proc {
          Timeout.timeout(@s[:timeout]) do
            get_title(t)
          end
        }
        callback = proc { |title|
          m.reply(title) if !title.nil? && !titles.include?(title)
          titles.push(title)
        }
        errback = proc { |e| Bot.log.info "Entitle: Failed to get title #{e}" }
        EM.defer(operation, callback, errback)
      end
    end
  end

  def get_title(url)
    Bot.log.info("Entitle: getting title of #{url}")
    # Storing into local var `html` bypasses bad unicode handling by Nokogiri
    # rubocop:disable Security/Open
    html = open(url, allow_redirections: :all)
    # rubocop:enable Security/Open
    doc = Nokogiri::HTML(html.read)
    doc.encoding = 'utf-8'
    doc.at_css('title').text.gsub(/ *\n */, ' ').strip
  end
end
