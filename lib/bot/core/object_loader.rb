# Methods for loading adapters/plugins with blacklists/whitelists
module Bot::Core::ObjectLoader
  def get_objects_dir(type)
    File.join(Bot::ROOT_DIR, @s["#{type}s".to_sym][:dir])
  end

  def load_objects(type, mode = :all)
    Bot.log.info "Loading #{type}s..."
    type = type.to_s
    objects_dir = get_objects_dir(type)

    Dir.foreach(objects_dir) do |f|
      next if ['.', '..'].include?(f)

      load_curry(type).call(f) if File.directory?(File.join(objects_dir, f)) && accepted?(type, f, mode)
    end
  end

  # Loads object type and adds a reference to it
  def load_curry(type)
    proc do |f|
      begin
        path = File.join(get_objects_dir(type), f.to_s)
        full_path = File.join(path, "#{f}.rb")
        Bot.log.info "Loading #{type} #{f} from #{full_path}..."
        load full_path

        types = {
          'plugin' => :plugin,
          'external_plugin' => :plugin,
          'adapter' => :adapter
        }
        actual_type = types[type]

        # Initialize the loaded object
        object = Bot.module_eval(actual_type.capitalize.to_s).const_get(f.capitalize).new(self)
        # And store a reference to that object in @types (eg. @plugins)
        # Store external plugins in the plugins list
        # TODO: check for name collisions
        # rubocop:disable Style/EvalWithLocation
        instance_eval("@#{actual_type}s")[f.downcase.to_sym] = object
        # rubocop:enable Style/EvalWithLocation
      rescue LoadError, StandardError, SyntaxError => e
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
