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

      load_objects(-> a { load_adapter(a) }, @settings[:adapters_dir])
      load_objects(-> p { load_plugin(p) }, @settings[:plugins_dir])
      Bot.log.info "#{@adapters.length} adapter(s) and #{@plugins.length} plugin(s) loaded."
    end

    def load_objects(proc, directory)
      directory = File.join(Bot::ROOT_DIR, directory)
      Dir.foreach(directory) do |f|
        next if f == '.' || f == '..'
        proc.call(f) if File.directory? File.join(directory, f)
      end
    end

    # Some redundancy between load_adapter and load_plugin but dynamically defining
    # the methods is overkill for the limited number of object types
    def load_adapter(adapter)
      Bot.log.info "Loading adapter #{adapter}..."
      load File.join(ROOT_DIR, @settings[:adapters_dir], adapter.to_s, "#{adapter}.rb")
      @adapters[adapter.to_sym] = Bot::Adapter.const_get(adapter.capitalize).new
    rescue => e
      Bot.log.warn "Failed to load #{adapter} - #{e}\n\t#{e.backtrace.join("\n\t")}"
    end

    def load_plugin(plugin)
      Bot.log.info "Loading plugin #{plugin}..."
      load File.join(ROOT_DIR, @settings[:plugins_dir], plugin.to_s, "#{plugin}.rb")
      @plugins[plugin.to_sym] = Bot::Plugin.const_get(plugin.capitalize).new
    rescue => e
      Bot.log.warn "Failed to load #{plugin} - #{e}\n\t#{e.backtrace.join("\n\t")}"
    end
  end
end