class Bot::Plugin
  require 'fileutils'

  def initialize(bot=nil)
    # Defaults
    plugin_name = self.class.to_s.split("::").last.downcase
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

  def load_settings(path=@settings_path)
    # Save defaults if no settings file exists
    save_settings unless File.file?(@settings_path)
    @s = JSON.parse(File.read(path), symbolize_names: true)
  end

  def save_settings(path=@settings_path)
    if !File.directory?(File.dirname(path))
      FileUtils.mkdir_p(File.dirname(path))
    end

    File.write(@settings_path, JSON.pretty_generate(@s))
  end
end