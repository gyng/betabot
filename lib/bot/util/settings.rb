module Bot::Util
  module Settings
    def load_settings(path=@settings_path)
      # Save defaults if no settings file exists
      save_settings unless File.file?(@settings_path)
      begin
        @s = JSON.parse(File.read(path), symbolize_names: true)
      rescue
        FileUtils.cp(path, "#{path}.bad") # Bad settings file, revert to defaults
        save_settings
      end
    end

    def save_settings(path=@settings_path)
      if !File.directory?(File.dirname(path))
        FileUtils.mkdir_p(File.dirname(path))
      end

      File.write(@settings_path, JSON.pretty_generate(@s))
    end
  end
end