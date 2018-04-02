class Bot::Plugin::Entitleri < Bot::Plugin
  require 'nokogiri'
  require 'open-uri'

  def initialize(bot)
    @s = {
      trigger: {
        entitleri: [
          :call, 0,
          'Entitle Reverse Image uses Google to tell you what an image link is.'
        ]
      },
      subscribe: true,
      filters: [
        '(http.*png(\/?\?.*)?$)',
        '(http.*gif(\/?\?.*)?$)',
        '(http.*jpg(\/?\?.*)?$)',
        '(http.*jpeg(\/?\?.*)?$)',
        '(http.*bmp(\/?\?.*)?$)',
        '(http.*webp(\/?\?.*)?$)'
      ],
      timeout: 20,
      google_query: 'https://www.google.com/searchbyimage?&image_url=',
      guess_selector: '.fKDtNb',
      user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:55.0) Gecko/20100101 Firefox/55.0'
    }

    super(bot)
  end

  def call(m)
    m.reply "Active filters: #{@s[:filters].join(', ')}"
  end

  def receive(m)
    check_filter(m)
  end

  def check_filter(m)
    return if m.text.nil?

    tokens = String.new(m.text).split(' ').uniq

    @s[:filters].each do |regex_s|
      regex = Regexp.new(regex_s)

      tokens.each do |t|
        next if regex.match(t).nil?

        Thread.new do
          begin
            Timeout.timeout(@s[:timeout]) do
              google_guess = get_guess_google(t)
              m.reply google_guess if !google_guess.nil? && !google_guess.empty?
            end
          rescue StandardError => e
            Bot.log.info "EntitleRI: Error in formulating guess: #{e} #{e.backtrace}"
          end
        end
      end
    end
  end

  def get_guess_google(url)
    Bot.log.info "EntitleRI: Getting Google best guess of #{url}"

    # Get redirect by spoofing User-Agent
    html = open(@s[:google_query] + url,
                'User-Agent' => @s[:user_agent],
                allow_redirections: :all,
                ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE,
                read_timeout: @s[:timeout])

    doc = Nokogiri::HTML(html.read)
    doc.encoding = 'utf-8'
    result = doc.css(@s[:guess_selector]).inner_text.strip
    Bot.log.info "EntitleRI: Got Google guess: #{result}"
    "Best guess for this image: #{result}"
  rescue StandardError => e
    Bot.log.info "Error in Entitleri#get_guess: #{e} #{e.backtrace}"
    nil
  end
end
