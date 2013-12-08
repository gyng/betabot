module Bot
  require 'json'
  require 'date'
  require 'logger'
  require 'timeout'
  require 'colorize'

  require_relative 'adapter'
  require_relative 'plugin'

  class << self
    attr_accessor :log

    def log
      if !@log
        @log = Logger.new(STDOUT)
        @log.level = Logger::WARN if ENV['TEST'] # Set in spec_helper.rb
        @log.formatter = -> severity, datetime, progname, message do
          color = case severity
            when 'FATAL';   :red
            when 'ERROR';   :red
            when 'WARN';    :red
            when 'INFO';    :default
            when 'DEBUG';   :default
            when 'UNKNOWN'; :default
          end
          "#{(severity[0] + ' ' + datetime.to_s + ' | ').colorize(color)}#{message}\n"
        end
      end
      @log
    end
  end

  class Core
    require_relative 'database'
    require_relative 'core/message'
    require_relative 'core/object_loader'
    require_relative 'core/authenticator'
    include Bot::Core::ObjectLoader

    attr_reader :adapters, :plugins, :settings, :shared_db, :auth
    START_TIME = Time.now

    def initialize(bot_settings_filename)
      @settings = nil
      @settings_filename = bot_settings_filename
      Bot.const_set('ROOT_DIR',     File.join(Dir.pwd, 'lib'))
      Bot.const_set('SETTINGS_DIR', File.join(Dir.pwd, 'lib', 'settings'))
      Bot.const_set('DATABASE_DIR', File.join(Dir.pwd, 'lib', 'database'))

      load_settings

      Bot.const_set('SHORT_TRIGGER', @settings[:short_trigger])
      @authenticator = Bot::Core::Authenticator.new
      @shared_db = Bot::Database.new(File.join(Bot::DATABASE_DIR, 'shared.sqlite3'))
      initialize_objects(:adapter)
      initialize_objects(:plugin)

      Bot.log.info "#{@adapters.length} adapter(s) and #{@plugins.length} plugin(s) loaded."

      @settings[:adapters][:autostart].each { |regex| start_adapters(regex) }
    end

    def load_settings
      @settings = JSON.parse(File.read(@settings_filename), symbolize_names: true)
    rescue => e
      Bot.log.fatal "Failed to load bot settings from file #{@settings_filename}. \
                     Check that file exists and permissions are set."
      raise e
    end

    def initialize_objects(type)
      if type == :adapter || type == nil
        @adapters = {}
        load_objects(:adapter)
      end

      if type == :plugin || type == nil
        @plugins = {}
        @plugin_mapping = {}
        @subscribed_plugins = []
        load_objects(:plugin)
      end
    end

    def start_adapters(regex='.*')
      send_to_objects(@adapters, :connect, regex)
    end

    def stop_adapters(regex='.*')
      send_to_objects(@adapters, :shutdown, regex)
    end

    def send_to_objects(list, method, regex='.*')
      selected = list.select { |k, v| k.to_s.match(/#{regex}/i) }
      selected.each { |k, v| v.send(method) }
    end

    def core_triggers(trigger, m)
      if auth(5, m)
        case trigger
        when 'shutdown'
          shutdown
        when 'restart'
          restart
        when 'reload'
          reload(:plugin)
          m.reply 'Reloaded.' if m.respond_to? :reply
        when 'useradd'
          @authenticator.make_account(m.args[0], m.args[1], m.args[2])
        else
          false
        end
      else
        case trigger
        when 'login'
          @authenticator.login(m)
        when 'logout'
          @authenticator.logout(m)
        end
      end
    end

    def trigger_plugin(trigger, m)
      if !core_triggers(trigger, m)
        # Check if plugin responds to trigger after core triggers
        if @plugin_mapping.has_key?(trigger.to_sym)
          plugin = @plugin_mapping[trigger.to_sym][:plugin]
          method = @plugin_mapping[trigger.to_sym][:method]
          required_auth_level = @plugin_mapping[trigger.to_sym][:required_auth_level]

          if @plugins.has_key?(plugin) && auth(required_auth_level, m)
            return @plugins[plugin].send(method.to_sym, m)
          end
        end
      end

      nil
    end

    def publish(m)
      # Plugin listens in to all messages
      @subscribed_plugins.each { |p| @plugins[p].receive(m)  }
    end

    def register_trigger(trigger, plugin, method, required_auth_level)
      @plugin_mapping[trigger.to_sym] = {
        plugin: plugin.to_sym,
        method: method.to_sym,
        required_auth_level: required_auth_level.to_i
      }
    end

    def subscribe_plugin(plugin)
      Bot.log.info "Subscribing plugin #{plugin.to_s}"
      @subscribed_plugins.push(plugin.to_sym)
    end

    def auth (level, m)
      @authenticator.auth(level, m)
    end

    def reload(type, name=nil)
      load_settings

      if (type == nil)
        initialize_objects(:adapter)
        initialize_objects(:plugin)
      elsif (name == nil)
        initialize_objects(type)
      else
        load_curry(type).call(name)
      end
    end

    def restart
      $restart = true
      shutdown
    end

    def shutdown
      # We don't want this to take too long, but give adapters some time to shutdown
      EM.add_timer(1) do
        stop_adapters
        EM.stop
      end
    end
  end
end