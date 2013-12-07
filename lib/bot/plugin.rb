class Bot::Plugin
  require 'fileutils'
  require_relative 'util/settings'
  include Bot::Util::Settings

  def initialize(bot=nil)
    @bot = bot
    plugin_name = self.class.to_s.split("::").last.downcase

    # Default settings
    @s ||= Hash.new([])
    @s[:trigger] = [plugin_name] unless @s.has_key?(:trigger)

    @settings_path ||= File.join(Bot::ROOT_DIR, 'plugins', plugin_name, 'settings', 'settings.json')
    load_settings

    @s[:trigger].each { |t| bot.register_trigger(t, plugin_name) } if bot
    bot.subscribe_plugin(plugin_name) if @s[:subscribe] == true

    Bot.log.info("Loaded plugin #{self.class.name} with triggers #{@s[:trigger].join(', ')}")
  end

  def call(m=nil)
    Bot.log.info("Called empty plugin #{self.class.name}")
  end

  def receive(m)
    # Receives every message from bot
  end
end