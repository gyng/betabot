module Bot
  require 'json'
  require 'date'
  require 'logger'

  require './bot/adapter'
  require './bot/plugin'


  class << self
    attr_accessor :log

    def log
      if !@log
        @log = Logger.new(STDOUT)
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
        @settings = JSON.parse(File.read(bot_settings_file), symbolize_names: true)
      rescue => e
        Bot.log.fatal "Failed to load bot settings from file #{bot_settings_file}. Check that file exists and permissions are set."
        raise e
      end

      load_objects(-> a { load_adapter(a) }, @settings[:adapters_dir])
      load_objects(-> p { load_plugin(a) }, @settings[:plugins_dir])
      Bot.log.info "#{@adapters.length} adapter(s) and #{@plugins.length} plugin(s) loaded."
    end

    def load_objects(proc, directory)
      directory = File.join(ROOT_DIR, directory)
      Dir.foreach(directory) do |f|
        next if f == '.' || f == '..'
        proc.call(f) if File.directory? File.join(directory, f)
      end
    end

    def load_adapter(adapter)
      Bot.log.info "Loading adapter #{adapter}..."
      load File.join(ROOT_DIR, @settings[:adapters_dir], adapter, "#{adapter}.rb")
      @adapters[adapter] = Bot::Adapter.const_get(adapter).new
    rescue => e
        puts "Failed to load #{adapter} - #{e}\n\t#{e.backtrace.join("\n\t")}"
    end

    def load_plugin(plugin)
      Bot.log.info "Loading plugin #{plugin}..."
      load File.join(ROOT_DIR, @settings[:plugins_dir], plugin, "#{plugin}.rb")
      @plugins[plugin] = Bot::Plugin.const_get(plugin).new
    rescue => e
        puts "Failed to load #{plugin} - #{e}\n\t#{e.backtrace.join("\n\t")}"
    end
  end
end