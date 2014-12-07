class Bot::Plugin::Entitleri < Bot::Plugin
  require 'nokogiri'
  require 'open-uri'

  def initialize(bot)
    @s = {
      trigger: { entitleri: [
        :call, 0,
        'Entitle Reverse Image harnesses the power of Google cloud technology ' +
        'and the information superhighway botnet to tell you what an image link is.'
      ]},
      subscribe: true,
      filters: ['http.*png', 'http.*gif', 'http.*jpg', 'http.*jpeg', 'http.*bmp'],
      timeout: 10,
      google_query: 'http://www.google.com/searchbyimage?&image_url=',
      guess_selector: '._hUb',
      user_agent: 'Mozilla/5.0 (Windows NT 6.0; rv:20.0) Gecko/20100101 Firefox/20.0'
    }
    super(bot)
  end

  def call(m)
    check_filter(m)
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
              guess = get_guess(result)
              m.reply(guess) unless guess.nil?
            end
          end

          # Prevent double-matching
          line.gsub!(result, '')
        end
      end
    end
  end

  def get_guess(url)
    puts "EntitleRI: Getting best guess of #{url}"

    # Get redirect by spoofing User-Agent
    html = open(@s[:google_query] + url,
      "User-Agent" => @s[:user_agent],
      allow_redirections: :all,
      ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE
    )

    doc = Nokogiri::HTML(html.read)
    doc.encoding = 'utf-8'
    doc.css(@s[:guess_selector]).inner_text
  end
end
