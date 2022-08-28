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
        '(http.*webp(\/?\?.*)?$)',
        "http.*format=(jpg|jpeg|png|bmp|gif).*"
      ],
      content_type_url_regex: '^http.*',
      content_type_regex: 'image/.*',
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

  def valid_content_type?(url)
    res = RestClient.head(url)
    res.headers[:content_type] =~ Regexp.new(@s[:content_type_regex])
  rescue StandardError => e
    Bot.log.info "#{self.class.name} - failed to get HEAD for #{url}: #{e}"
    false
  end

  def check_filter(m)
    return if m.text.nil?

    tokens = String.new(m.text).split(' ').uniq

    matches = []
    checked_head = []

    # rubocop:disable Metrics/BlockLength
    @s[:filters].each do |regex_s|
      regex = Regexp.new(regex_s)
      next unless @s[:imginfer_key]

      tokens.each do |t|
        next if checked_head.include?(t)
        next if matches.include?(t)
        # Check Content-Type via HEAD
        if regex.match(t).nil?
          if t =~ Regexp.new(@s[:content_type_url_regex])
            if !valid_content_type?(t)
              checked_head.append(t) 
              next
            end
            Bot.log.info "#{self.class.name} - Image detected (content-type): #{t}"
          else
            next
          end
        end
        matches.append(t)
      end
    end

    matches.uniq.each do |match|
      Bot.log.info "#{self.class.name} - Inferring: #{match}"
      imginfer_operation = proc {
        Timeout.timeout(@s[:timeout]) do
          get_guess_imginfer(match)
        end
      }
      imginfer_callback = proc { |imginfer_guess|
        begin
          if imginfer_guess
            if imginfer_guess[:yolov5][:results].length.positive?
              m.reply "yolov5: #{imginfer_guess[:yolov5][:str_repr].split("\n")[0]}"
            end
            if imginfer_guess[:easyocr][:results].length.positive?
              str = imginfer_guess[:easyocr][:str_repr]
                .split(' ')[0..20]
                .join(' ')[0..400]
              m.reply "easyocr: #{str}"
            end
            if imginfer_guess[:danbooru2018][:results].length.positive?
              str = imginfer_guess[:danbooru2018][:str_repr]
                .split(' ')[0..21]
                .join(' ')[0..400]
                .gsub("age_rating_s", "age_rating_s".green)
                .gsub("age_rating_q", "age_rating_q".brown)
                .gsub("age_rating_e", "age_rating_e".red)
              m.reply "danbooru2018: #{str}"
            end
          end
        rescue StandardError => e
          Bot.log.info "EntitleRI: Failed to parse imginfer response #{e} #{e.backtrace}"
          Bot.log.warn "EntitleRI: Failed to parse imginfer response #{imginfer_guess}"
        end
      }
      imginfer_errback = proc { |e| Bot.log.info "EntitleRI: Failed to get imginfer guess #{e}" }
      EM.defer(imginfer_operation, imginfer_callback, imginfer_errback)
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
