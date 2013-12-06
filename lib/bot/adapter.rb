class Bot::Adapter
  def initialize
    Bot.log.info "Loaded adapter #{self.class.name}"
    super
  end

  def connect
    Bot.log.info "Empty connect method: not connecting adapter #{self.class.name}"
  end

  def disconnect
  end
end