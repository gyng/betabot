class Bot::Plugin
  def initialize(bot=nil)
    Bot.log.info("Loaded plugin #{self.class.name}")
  end
end