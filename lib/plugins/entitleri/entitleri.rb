class Bot::Plugin::Entitleri < Bot::Plugin
  require 'nokogiri'
  require 'open-uri'

  def initialize(bot)
    @s = {
      trigger: {
        entitleri: [
          :call, 0,
          'Entitle Reverse Image uses Google and MS Vision API to tell you what an image link is.'
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
      guess_selector: '._hUb',
      user_agent: 'Mozilla/5.0 (Windows NT 6.0; rv:20.0) Gecko/20100101 Firefox/20.0',
      microsoft_computer_vision_api_key: 'Get from: https://www.microsoft.com/cognitive-services/en-US/subscriptions'
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
    tokens = String.new(m.text).split(' ').uniq

    @s[:filters].each do |regex_s|
      regex = Regexp.new(regex_s)

      tokens.each do |t|
        next if regex.match(t).nil?

        Thread.new do
          begin
            Timeout.timeout(@s[:timeout]) do
              guess_text = []

              google_guess = get_guess_google(t)
              guess_text.push(google_guess) if !google_guess.nil? && !google_guess.empty?

              guess_microsoft = get_guess_microsoft(t)
              guess_text.push(format_guess_microsoft(guess_microsoft)) if !guess_microsoft.nil?

              if !guess_text.empty?
                guess_text = guess_text.join(', ')
                m.reply guess_text
              end
            end
          rescue StandardError => e
            Bot.log.info "EntitleRI: Error in formulating guess: #{e} #{e.backtrace}"
          end
        end
      end
    end
  end

  def format_guess_microsoft(guess)
    return nil if guess.nil? || guess[:description].nil?
    s = []

    caption = guess[:description][:captions][0]
    s.push caption[:text].to_s if caption[:confidence] > 0.25

    if guess[:adult][:isAdultContent]
      s.push '🔞 NSFW 🔞'
    elsif guess[:adult][:isRacyContent]
      s.push 'maybe NSFW'
    end

    s.join(', ')
  end

  def get_guess_microsoft(url)
    Bot.log.info "EntitleRI: Getting Microsoft image analysis of #{url}"
    uri = URI('https://api.projectoxford.ai/vision/v1.0/analyze')
    uri.query = URI.encode_www_form(
      'visualFeatures' => 'Categories,Description,Tags,Faces,ImageType,Color,Adult',
      'details' => 'Celebrities'
    )

    request = Net::HTTP::Post.new(uri.request_uri)
    request['Content-Type'] = 'application/json'
    request['Ocp-Apim-Subscription-Key'] = @s[:microsoft_computer_vision_api_key]
    request.body = { url: url }.to_json

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: @s[:timeout]) do |http|
      http.request(request)
    end

    parsed = JSON.parse(response.body, symbolize_names: true)
    Bot.log.info "EntitleRI: parsed image analysis: #{parsed.inspect}"
    parsed
  rescue StandardError => e
    Bot.log.info "Error in Entitleri#get_guess_microsoft: #{e} #{e.backtrace}"
    nil
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
    result
  rescue StandardError => e
    Bot.log.info "Error in Entitleri#get_guess: #{e} #{e.backtrace}"
    nil
  end
end
