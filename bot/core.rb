module Bot
  require 'json'
  require 'date'
  require 'logger'

  require './bot/adapter'

  $logger = Logger.new(STDOUT)
  $logger.formatter = proc do |severity, datetime, progname, message|
    "#{severity[0]} #{datetime} | #{message}\n"
  end

  class Core
    def initialize(bot_settings_file)
      @START_TIME = DateTime.new
      @adapters = {}
      @plugins = {}

      begin
        @settings = JSON.parse(File.read(bot_settings_file), symbolize_names: true)
      rescue => e
        $logger.fatal "Failed to load bot settings from file #{bot_settings_file}. Check that file exists and permissions are set.\n"
        $logger.fatal "\n\n\t#{e}\n\n\tBacktrace:\n\t#{e.backtrace.join("\n\t")}"
        abort
      end

      load_objects(Proc.new { |a| load_adapter(a) }, @settings[:adapters_dir])
      $logger.info "#{@adapters.length} adapter(s) loaded"
      load_objects(Proc.new { |a| load_plugin(a) }, @settings[:plugins_dir])
      $logger.info "#{@plugins.length} plugin(s) loaded"
    end

    def load_objects(proc, directory)
      directory = File.join(ROOT_DIR, directory)
      Dir.foreach(directory) do |f|
        next if f == '.' || f == '..'
        proc.call(f) if File.directory? File.join(directory, f)
      end
    end

    def load_adapter(adapter)
      $logger.info "Loading adapter #{adapter}..."
      load File.join(ROOT_DIR, @settings[:adapters_dir], adapter, "#{adapter}.rb")
      @adapters[adapter] = Bot::Adapters.const_get(adapter).new
    rescue => e
        puts "Failed to load #{adapter} - #{e}\n\t#{e.backtrace.join("\n\t")}"
    end

    def load_plugin(plugin)
      $logger.info "Loading plugin #{plugin}..."
      load File.join(ROOT_DIR, @settings[:plugins_dir], plugin, "#{plugin}.rb")
      @plugins[plugin] = Bot::Plugins.const_get(plugin).new
    rescue => e
        puts "Failed to load #{plugin} - #{e}\n\t#{e.backtrace.join("\n\t")}"
    end
  end
end