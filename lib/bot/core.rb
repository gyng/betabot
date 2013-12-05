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
    require_relative 'core/object_loader'
    include Bot::Core::ObjectLoader

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