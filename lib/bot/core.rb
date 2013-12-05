module Bot
  require 'json'
  require 'date'
  require 'logger'

  require_relative './adapter'
  require_relative './plugin'

  class << self
    attr_accessor :log

    def log
      if !@log
        @log = Logger.new(STDOUT)
        @log.level = Logger::WARN if ENV['TEST'] # Set in spec_helper.rb
        @log.formatter = -> severity, datetime, progname, message do
          "#{severity[0]} #{datetime} | #{message}\n"
        end
      end
      @log
    end
  end

  class Core
    attr_reader :adapters, :plugins
    START_TIME = Time.now

    def initialize(bot_settings_file)
      @adapters = {}
      @plugins = {}

      begin
        Bot.const_set("ROOT_DIR", File.join(Dir.pwd, "lib")) unless defined?(Bot::ROOT_DIR)
        @settings = JSON.parse(File.read(bot_settings_file), symbolize_names: true)
      rescue => e
        Bot.log.fatal "Failed to load bot settings from file #{bot_settings_file}. \
                       Check that file exists and permissions are set."
        raise e
      end

      load_objects('adapter')
      load_objects('plugin')
      Bot.log.info "#{@adapters.length} adapter(s) and #{@plugins.length} plugin(s) loaded."
    end

    def get_objects_dir(type)
      File.join(Bot::ROOT_DIR, @settings["#{type}s_dir".to_sym])
    end

    def load_objects(type)
      objects_dir = get_objects_dir(type)
      Dir.foreach(objects_dir) do |f|
        next if f == '.' || f == '..'
        load_curry(type).call(f) if File.directory?(File.join(objects_dir, f))
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
          object = Bot.module_eval("#{type.capitalize}").const_get(f.capitalize).new
          # And store a reference to that object in @types (eg. @plugins)
          instance_eval("@#{type}s")[f.to_sym] = object
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

    def reload(type, name=nil)
      if (type == nil)
        load_objects('adapter')
        load_objects('plugin')
      elsif (name == nil)
        load_objects(type)
      else
        load_curry(type).call(name)
      end
    end

    def restart
    end

    def shutdown
    end
  end
end