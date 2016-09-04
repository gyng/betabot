class Bot::Plugin
  require 'fileutils'
  require_relative 'util/settings'
  include Bot::Util::Settings

  def initialize(bot = nil)
    @bot = bot
    plugin_name = self.class.to_s.split('::').last.downcase

    # Default settings
    @s ||= Hash.new([])
    @s[:trigger] = { plugin_name.to_sym => [:call, 0] } unless @s.key?(:trigger)

    root_dir = defined?(Bot) && defined?(Bot::ROOT_DIR) ? Bot::ROOT_DIR : File.join(Dir.pwd, 'lib')
    @settings_path ||= File.join(root_dir, 'plugins', plugin_name, 'settings', 'settings.json')
    load_settings

    @s[:trigger].each { |trigger, opts| bot.register_trigger(trigger, plugin_name, *opts) } if bot
    bot.subscribe_plugin(plugin_name) if @s[:subscribe] == true

    Bot.log.info("Loaded plugin #{self.class.name}")
  end

  def call(_m)
    Bot.log.info("Called empty plugin #{self.class.name}")
  end

  def receive(m)
    # Receives every message from bot
  end

  def auth(level, m)
    @bot.auth(level, m)
  end

  def auth_r(level, m)
    if auth(level, m)
      true
    else
      m.reply('You are unauthorised for this.')
      false
    end
  end
end
