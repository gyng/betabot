# rubocop:disable Lint/MissingCopEnableDirective
# rubocop:disable Metrics/BlockLength
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/PerceivedComplexity
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
        'http.*format=(jpg|jpeg|png|bmp|gif|webp).*'
      ],
      content_type_url_regex: '^http.*',
      content_type_regex: 'image/.*',
      timeout: 30,
      imginfer_key: '',
      imginfer_infer_endpoint: 'http://localhost:8080/infer',
      openapi_key: ''
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

    @s[:filters].each do |regex_s|
      regex = Regexp.new(regex_s)
      next unless @s[:imginfer_key]

      tokens.each do |t|
        next if checked_head.include?(t)
        next if matches.include?(t)

        # Check Content-Type via HEAD
        if regex.match(t).nil?
          # rubocop:disable Style/GuardClause
          if t =~ Regexp.new(@s[:content_type_url_regex])
            if !valid_content_type?(t)
              checked_head.append(t)
              next
            end
            Bot.log.info "#{self.class.name} - Image detected (content-type): #{t}"
          else
            next
          end
          # rubocop:enable Style/GuardClause
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
            # if imginfer_guess[:yolov5][:results].length.positive?
            #   m.reply "yolov5: #{imginfer_guess[:yolov5][:str_repr].split("\n")[0]}"
            # end
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
                    .gsub('age_rating_s', 'age_rating_s'.green)
                    .gsub('age_rating_q', 'age_rating_q'.brown)
                    .gsub('age_rating_e', 'age_rating_e'.red)

              # OpenAPI summary post processing
              transcript = ""
              # Don't hardcode exclusion list
              if imginfer_guess[:easyocr][:results].length.positive? && !match.include? "aibi"
                transcript = imginfer_guess[:easyocr][:str_repr]
                             .split(' ')[0..20]
                             .join(' ')[0..400]
              end

              Bot.log.info "EntitleRI: Tags #{str}"

              if @s[:openapi_key]
                do_openapi(m, str, transcript)
              else
                # Don't reply unless openapi fails: do the reply in do_openapi instead
                m.reply "danbooru2018: #{str}"
              end
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
  end

  def do_openapi(m, tags_s, text)
    operation = proc {
      Timeout.timeout(@s[:timeout]) do
        Bot.log.info "EntitleRI: Getting openapi enhanced imginfer results for #{tags_s}"

        prompt = "I have a creative writing class homework assignment I need your help with." \
                 "Please analyze these image tags generated from an image by an image " \
                 "classifier ML model trained on Danbooru and comment on any speculated " \
                 "events happening in the image with context." \
                 "Provide your answer in the style of a sardonic one-liner written by Bloomberg's Matt Levine. " \
                 "Assume the tags provided are correct. " \
                 "Assume the text transcript, if available, can have errors. "\
                 "The text transcript is verified by a human to be relevant and related to the image. " \
                 "Do not talk about the image classifier, tags, or transcript in the answer as it is supposed to " \
                 "be a secret. " \
                 "Put your actual answer in curly braces like this: {{answer}}\n\n" \
                 "tags: #{tags_s} \n\n" \
                 "text transcript: #{text ? text : "no text"}"

        body = { "model": "gpt-3.5-turbo", "messages": [
          { "role": "system", "content": "You are a helpful assistant." },
          { "role": "user", "content": prompt }
        ] }
        body = body.to_json
        res = JSON.parse(RestClient.post("https://api.openai.com/v1/chat/completions", body, {
                                           'Content-Type' => 'application/json',
                                           'Authorization' => "Bearer #{@s[:openapi_key]}"
                                         }), symbolize_names: true)
      end
    }
    callback = proc { |res|
      begin
        guess = res[:choices][0][:message][:content]
        guess = guess.match(/(?<=\{\{).*?(?=\}\})/)[0]

        if guess
          m.reply "gpt-3.5-turbo: #{guess}"
        end
      rescue StandardError => e
        m.reply "danbooru2018: #{tags_s}"
        Bot.log.info "EntitleRI: Failed to parse openapi response #{e} #{e.backtrace}"
      end
    }
    errback = proc { |e| Bot.log.info "EntitleRI: Failed to get openapi guess #{e}" }
    EM.defer(operation, callback, errback)
  rescue StandardError => e
    Bot.log.info "EntitleRI: Failed to parse openapi response #{e} #{e.backtrace}"
    Bot.log.warn "EntitleRI: Failed to parse openapi response #{imginfer_guess}"
  end
  # rubocop:enable Metrics/CyclomaticComplexity

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
