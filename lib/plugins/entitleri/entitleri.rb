class Bot::Plugin::Entitleri < Bot::Plugin
  require 'nokogiri'
  require 'open-uri'

  def initialize(bot)
    @s = {
      trigger: {
        entitleri: [
          :call, 0,
          'Entitle Reverse Image harnesses the power of Google cloud technology ' \
          'and the information superhighway botnet to tell you what an image link is.'
        ],
        lastimage: [
          :last_image, 0,
          'lastimage [more]: Show the image analysis for the last image. more returns ' \
          'the entire cached response.'
        ]
      },
      subscribe: true,
      filters: ['http.*png', 'http.*gif', 'http.*jpg', 'http.*jpeg', 'http.*bmp'],
      timeout: 20,
      google_query: 'https://www.google.com/searchbyimage?&image_url=',
      guess_selector: '._hUb',
      user_agent: 'Mozilla/5.0 (Windows NT 6.0; rv:20.0) Gecko/20100101 Firefox/20.0',
      microsoft_computer_vision_api_key: 'Get from: https://www.microsoft.com/cognitive-services/en-US/subscriptions'
    }

    @last_images = {}

    super(bot)
  end

  def call(m)
    check_filter(m)
  end

  def receive(m)
    check_filter(m)
  end

  def last_image(m)
    more_mode = m.args[0] == 'more' || m.args[0] == '-m'
    last_image = @last_images[m.channel]

    if last_image.nil?
      m.reply 'No last image.'
    else
      clipart_types = ['Non-clipart', 'ambiguous', 'normal-clipart', 'good-clipart']
      line_drawing_types = ['Non-LineDrawing', 'LineDrawing']
      caption = last_image[:description][:captions][0]
      clipart_type = clipart_types[last_image[:imageType][:clipArtType]]
      line_drawing_type = line_drawing_types[last_image[:imageType][:lineDrawingType]]

      m.reply "#{caption[:text]}, confidence: #{caption[:confidence].round(2)}, #{clipart_type}, #{line_drawing_type}"
      m.reply last_image.to_s if more_mode
    end
  end

  def check_filter(m)
    line = String.new(m.text)

    @s[:filters].each do |regex|
      results = line.scan(Regexp.new(regex))

      next if results.empty?

      results.each do |result|
        Thread.new do
          timeout(@s[:timeout]) do
            guess_text = []

            guess = get_guess(result)
            guess_text.push(guess) if !guess.nil?

            begin
              @last_images[m.channel] = nil
              guess_microsoft = get_guess_microsoft(result)
              puts guess_microsoft.inspect
              if !guess_microsoft.nil? && guess_microsoft[:code].nil?
                caption = guess_microsoft[:description][:captions][0]
                guess_text.push(caption[:text]) if caption[:confidence] > 0.25
                @last_images[m.channel] = guess_microsoft

                if guess_microsoft[:adult][:isAdultContent]
                  guess_text.push('🔞 NSFW 🔞')
                elsif guess_microsoft[:adult][:isRacyContent]
                  guess_text.push('maybe NSFW')
                end
              end

              m.reply(guess_text.join(', ')) if !guess_text.empty?
            rescue StandardError => e
              puts "EntitleRI: Error in formulating guess: #{e} #{e.backtrace}"
            end
          end
        end

        # Prevent double-matching
        line.gsub!(result, '')
      end
    end
  end

  def get_guess_microsoft(url)
    puts "EntitleRI: Getting image analysis of #{url}"
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
    puts "EntitleRI: parsed image analysis: #{parsed.inspect}"
    parsed
  rescue StandardError => e
    puts "Error in Entitleri#get_guess_microsoft: #{e} #{e.backtrace}"
    nil
  end

  def get_guess(url)
    puts "EntitleRI: Getting best guess of #{url}"

    # Get redirect by spoofing User-Agent
    html = open(@s[:google_query] + url,
                'User-Agent' => @s[:user_agent],
                allow_redirections: :all,
                ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE,
                read_timeout: @s[:timeout])

    doc = Nokogiri::HTML(html.read)
    doc.encoding = 'utf-8'
    result = doc.css(@s[:guess_selector]).inner_text
    puts "EntitleRI: Got Google guess: #{result}"
    result
  rescue StandardError => e
    puts "Error in Entitleri#get_guess: #{e} #{e.backtrace}"
    nil
  end
end
