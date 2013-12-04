class Bot::Adapter
  def initialize
    Bot.log.info("Loaded adapter #{self.class.name}")
  end
end