class Bot::Adapter
  def initialize(bot=nil)
    @bot = bot
    Bot.log.info "Loaded adapter #{self.class.name}"
    # super
  end

  def connect
    Bot.log.info "Empty connect method: not connecting adapter #{self.class.name}"
  end

  def disconnect
  end

  def shutdown
  end

  def trigger_plugin(trigger)
    @bot.trigger_plugin(trigger)
  end
end