class Bot::Plugin::Ping < Bot::Plugin
  def initialize(bot)
    # Defaults
    @s = {
      trigger: ['dong'],
      subscribe: false
    }
    super(bot)
  end

  def call(m=nil)
    m.reply('pong')
  end

  def receive(m)
    # Receiving!
  end
end