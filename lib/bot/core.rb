module Bot
  require 'json'
  require 'date'
  require 'logger'
  require 'timeout'

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
            when 'INFO';    :gray
            when 'DEBUG';   :gray
            when 'UNKNOWN'; :gray
          end
          "#{(severity[0] + ' ' + datetime.to_s + ' | ').send(color)}#{message}\n"
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
    require_relative 'util/settings'

    include Bot::Core::ObjectLoader
    include Bot::Util::Settings

    attr_reader :adapters, :plugins, :settings, :shared_db, :auth
    START_TIME = Time.now

    def initialize(bot_settings_path)
      Bot.const_set('ROOT_DIR',     File.join(Dir.pwd, 'lib'))              if !Bot.const_defined?('ROOT_DIR')
      Bot.const_set('SETTINGS_DIR', File.join(Dir.pwd, 'lib', 'settings'))  if !Bot.const_defined?('SETTINGS_DIR')
      Bot.const_set('DATABASE_DIR', File.join(Dir.pwd, 'lib', 'databases')) if !Bot.const_defined?('DATABASE_DIR')

      @s = nil
      @settings_path = bot_settings_path
      load_settings

      Bot.const_set('SHORT_TRIGGER', @s[:short_trigger]) if !Bot.const_defined?('SHORT_TRIGGER')
      @authenticator = Bot::Core::Authenticator.new

      @shared_db = Bot::Database.new(File.join(Bot::DATABASE_DIR, 'shared.sqlite3')) if @s[:create_shared_db]
      initialize_objects(:adapter, @s[:adapters][:load_mode])
      initialize_objects(:plugin, @s[:plugins][:load_mode])
      Bot.log.info "#{@adapters.length} adapter(s) and #{@plugins.length} plugin(s) loaded."
      @s[:adapters][:autostart].each { |regex| start_adapters(regex) }
    end

    def initialize_objects(type, mode)
      if type == :adapter || type == nil
        @adapters = {}
        load_objects(:adapter, mode)
      end

      if type == :plugin || type == nil
        @plugins = {}
        @plugin_mapping = {}
        @subscribed_plugins = []
        load_objects(:plugin, mode)
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
          m.reply "User #{m.args[0]} added."
        when 'blacklist_adapter'
          blacklist(:adapter, m.args[0])
          m.reply "Adapter #{m.args[0]} blacklisted. Restart for this to take effect."
        when 'unblacklist_adapter'
          unblacklist(:adapter, m.args[0])
          m.reply "Adapter #{m.args[0]} unblacklisted. Restart for this to take effect."
        when 'blacklist_plugin'
          blacklist(:plugin, m.args[0])
          m.reply "Plugin #{m.args[0]} blacklisted. Reload for this to take effect."
        when 'unblacklist_plugin'
          unblacklist(:plugin, m.args[0])
          m.reply "Plugin #{m.args[0]} unblacklisted. Reload for this to take effect."
        when 'blacklist'
          m.reply "Adapters: " + @s[:adapters][:blacklist].join(', ')
          m.reply "Plugins: " + @s[:plugins][:blacklist].join(', ')
        else
          false
        end
      end

      case trigger
      when 'login'
        @authenticator.login(m)
      when 'logout'
        @authenticator.logout(m)
      when 'help'
        query = m.args[0].to_sym if m.args[0].is_a?(String)
        if @plugin_mapping.has_key?(query)
          m.reply @plugin_mapping[query][:help]
        else
          m.reply "Use help <trigger> for details. Triggers: #{@plugin_mapping.keys.join(', ')}"
        end
      end
    end

    def blacklist(type, name)
      @s["#{type}s".to_sym][:blacklist].push(name).uniq!
      save_settings
    end

    def unblacklist(type, name)
      @s["#{type}s".to_sym][:blacklist].delete(name)
      save_settings
    end

    def trigger_plugin(trigger, m)
      if !core_triggers(trigger, m)
        # Check if plugin responds to trigger after core triggers
        if @plugin_mapping.has_key?(trigger.to_sym)
          plugin = @plugin_mapping[trigger.to_sym][:plugin]
          method = @plugin_mapping[trigger.to_sym][:method]
          required_auth_level = @plugin_mapping[trigger.to_sym][:required_auth_level]

          if @plugins.has_key?(plugin) && auth(required_auth_level, m)
            begin
              @plugins[plugin].send(method.to_sym, m)
            rescue Exception => e
              Bot.log.error "#{plugin} ##{method} - #{e}\n#{e.backtrace.join("\n")}}"
            end
          end
        end
      end

      nil
    end

    def publish(m)
      # Plugin listens in to all messages
      @subscribed_plugins.each { |p| @plugins[p].receive(m)  }
    end

    def register_trigger(trigger, plugin, method, required_auth_level, help='No help.')
      @plugin_mapping[trigger.to_sym] = {
        plugin: plugin.to_sym,
        method: method.to_sym,
        required_auth_level: required_auth_level.to_i,
        help: help
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
      $shutdown = true
      EM.add_timer(1) do
        stop_adapters
        EM.stop
      end
    end
  end
end