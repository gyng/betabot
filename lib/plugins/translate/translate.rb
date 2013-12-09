class Bot::Plugin::Translate < Bot::Plugin
  def initialize(bot)
    @s = {
      trigger: { translate: [
        :translate, 0,
        'translate [<from> <to>] text. Translates text. Autodetects locale if not provided. ' +
        'Example locales: en, ja, es, fr, de, ko'
      ]},
      subscribe: false,
      bing_client_id: nil,
      bing_api_key: nil,
      azure_account_key: nil,
      default_target_locale: :en
    }
    super(bot)

    # Follow the instructions at https://github.com/CodeBlock/bing_translator-gem
    # to get the required keys.
    @translator = BingTranslator.new(@s[:bing_client_id], @s[:bing_api_key], true, @s[:azure_account_key])
  end

  def translate(m)
    if @s[:bing_client_id] && @s[:bing_api_key] && @s[:azure_account_key]
      Thread.new do
        if m.args[0] =~ /^.{2}$/ && m.args[1] =~ /^.{2}$/
          m.reply @translator.translate(m.args[2..-1].join(' '), from: m.args[0], to: m.args[1])
        else
          m.reply @translator.translate(m.args.join(' '), to: @s[:default_target_locale])
        end
      end
    else
      m.reply 'Translate has not been set up with the required keys.'
    end
  end
end