# Methods for loading adapters/plugins with blacklists/whitelists
module Bot::Core::ObjectLoader
  def get_objects_dir(type)
    File.join(Bot::ROOT_DIR, @s["#{type}s".to_sym][:dir])
  end

  def load_objects(type, mode)
    type = type.to_s
    objects_dir = get_objects_dir(type)

    Dir.foreach(objects_dir) do |f|
      next if f == '.' || f == '..'
      if File.directory?(File.join(objects_dir, f)) && accepted?(type, f, mode)
        load_curry(type).call(f)
      end
    end
  end

  # Loads object type and adds a reference to it
  def load_curry(type)
    Proc.new do |f|
      begin
        Bot.log.info "Loading #{type} #{f}..."
        path =  File.join(get_objects_dir(type), f.to_s)
        load File.join(path, "#{f}.rb")
        # Initialize the loaded object
        object = Bot.module_eval("#{type.capitalize}").const_get(f.capitalize).new(self)
        # And store a reference to that object in @types (eg. @plugins)
        instance_eval("@#{type}s")[f.downcase.to_sym] = object
      rescue => e
        Bot.log.warn "Failed to load #{f} - #{e}\n\t#{e.backtrace.join("\n\t")}"
      end
    end
  end

  def load_adapter(adapter)
    load_curry('adapter').call(adapter)
  end

  def load_plugin(plugin)
    load_curry('plugin').call(plugin)
  end

  def accepted?(type, name, mode)
    mode = mode.to_sym

    if mode == :all
      true
    elsif mode == :whitelist
      @s["#{type}s".to_sym][mode].include?(name)
    elsif mode == :blacklist
      !@s["#{type}s".to_sym][mode].include?(name)
    end
  end
end