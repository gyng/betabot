class Bot::Adapter
  require_relative 'util/settings'
  include Bot::Util::Settings

  def initialize(bot=nil)
    @bot = bot
    adapter_name = self.class.to_s.split("::").last.downcase

    # Default settings
    @s ||= Hash.new([])

    @settings_path ||= File.join(Bot::ROOT_DIR, 'adapters', adapter_name, 'settings', 'settings.json')
    load_settings

    Bot.log.info "Loaded adapter #{self.class.name}"
  end

  def connect
    Bot.log.info "Empty connect method: not connecting adapter #{self.class.name}"
  end

  def disconnect
  end

  def shutdown
  end

  def trigger_plugin(trigger, m=nil)
    @bot.trigger_plugin(trigger, m)
  end

  def publish(m)
    @bot.publish(m)
  end
end