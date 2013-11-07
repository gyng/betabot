class Bot::Plugin
  def initialize
    Bot.log.info("Loaded plugin #{self.class.name}")
  end
end