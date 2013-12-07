class Bot::Plugin::Ping < Bot::Plugin
  def initialize(bot)
    # Defaults. Settings are persistent. A settings file is created if it does not exist
    # in ./settings/settings.json. See: #save_settings and #load_settings
    #
    # Required plugin settings:
    # trigger:   { trigger_word: [method_to_call, required_auth_level] }
    # subscribe: Subscribe to Bot publish? (ie. usually all non-sensitive messages)
    # help:      Not required, but useful to have.
    #
    # You can add more settings for the bot (eg. ping_message: 'ding dong') and access
    # it with @s[:ping_message]
    @s = {
      trigger: { ping: [:call, 0] },
      subscribe: false,
      help: 'Ping pong dong gong'
    }
    super(bot)
  end

  # The method called is defined in @s[:trigger]. In this case, it's #call.
  def call(m=nil)
    m.reply('pong')
  end

  # This method receives published messages.
  def receive(m)
    # Receiving!
  end
end