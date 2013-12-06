class Bot::Plugin::Ping < Bot::Plugin
  def initialize(bot)
    # Defaults
    @s = {
      trigger: ['dong']
    }
    super(bot)
  end

  def call(m=nil)
    m.reply('pong')
  end
end