class Bot::Plugin
  require 'fileutils'

  def initialize(bot=nil)
    # Defaults
    plugin_name = self.class.to_s.split("::").last.downcase
    @s ||= Hash.new([])
    @s[:trigger] ||= plugin_name
    @settings_path ||= File.join(Bot::ROOT_DIR, 'plugins', plugin_name, 'settings', 'settings.json')
    load_settings

    Bot.log.info("Loaded plugin #{self.class.name}")
  end

  def call(m=nil)
    Bot.log.info("Called empty plugin #{self.class.name}")
  end

  def load_settings(path=@settings_path)
    # save defaults if no settings file exists
    save_settings unless File.file?(@settings_path)
    @s = JSON.parse(File.read(path))
  end

  def save_settings(path=@settings_path)
    if !File.directory?(File.dirname(path))
      FileUtils.mkdir_p(File.dirname(path))
    end

    File.write(@settings_path, JSON.pretty_generate(@s))
  end
end