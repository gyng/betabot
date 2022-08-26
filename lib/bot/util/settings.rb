# rubocop:disable Style/ClassAndModuleChildren
module Bot::Util
  module Bot::Util::Settings
    def load_settings(path = @settings_path)
      # Save defaults if no settings file exists
      save_settings unless File.file?(path)
      begin
        @s = JSON.parse(File.read(path).force_encoding('utf-8'), symbolize_names: true)
      rescue StandardError
        FileUtils.cp(path, "#{path}.bad") # Bad settings file, revert to defaults
        save_settings
      end
    end

    def save_settings(path = @settings_path)
      FileUtils.mkdir_p(File.dirname(path)) unless File.directory?(File.dirname(path))
      File.write(path, JSON.pretty_generate(@s))
    end
  end
end
# rubocop:enable Style/ClassAndModuleChildren
