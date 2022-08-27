class Bot::Plugin::Entitleri < Bot::Plugin
  require 'nokogiri'
  require 'open-uri'

  def initialize(bot)
    @s = {
      trigger: {
        entitleri: [
          :call, 0,
          'Entitle Reverse Image uses imginfer (https://github.com/gyng/imginfer)' \
          'to tell you what an image link contains.'
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
      imginfer_key: '',
      imginfer_infer_endpoint: 'http://localhost:8080/infer'
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

    # rubocop:disable Metrics/BlockLength
    @s[:filters].each do |regex_s|
      regex = Regexp.new(regex_s)

      tokens.each do |t|
        next if regex.match(t).nil?
        next unless @s[:imginfer_key]

        imginfer_operation = proc {
          Timeout.timeout(@s[:timeout]) do
            get_guess_imginfer(t)
          end
        }
        imginfer_callback = proc { |imginfer_guess|
          begin
            if imginfer_guess
              if imginfer_guess[:yolov5][:results].length.positive?
                m.reply "yolov5: #{imginfer_guess[:yolov5][:str_repr].split("\n")[0]}"
              end
              if imginfer_guess[:easyocr][:results].length.positive?
                m.reply "easyocr: #{imginfer_guess[:easyocr][:str_repr].split(' ')[0..20].join(' ')}"
              end
            end
          rescue StandardError
            Bot.log.warn "EntitleRI: Failed to parse imginfer response #{imginfer_guess}"
          end
        }
        imginfer_errback = proc { |e| Bot.log.info "EntitleRI: Failed to get imginfer guess #{e}" }
        EM.defer(imginfer_operation, imginfer_callback, imginfer_errback)
      end
    end
    # rubocop:enable Metrics/BlockLength
  end

  def get_guess_imginfer(url)
    Bot.log.info "EntitleRI: Getting imginfer results for #{url}"

    body = { uri: url }
    body = body.to_json
    JSON.parse(RestClient.post(@s[:imginfer_infer_endpoint], body, {
                                 'Content-Type' => 'application/json',
                                 'Authorization' => "Bearer #{@s[:imginfer_key]}"
                               }), symbolize_names: true)
  rescue StandardError => e
    Bot.log.info "Error in Entitleri#get_guess_imginfer: #{e} #{e.backtrace}"
    nil
  end
end
