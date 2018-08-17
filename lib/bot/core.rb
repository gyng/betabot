module Bot
  require 'json'
  require 'date'
  require 'logger'
  require 'timeout'

  require_relative 'adapter'
  require_relative 'plugin'
  require_relative 'util/logger'

  class Core
    require_relative 'database'
    require_relative 'core/message'
    require_relative 'core/object_loader'
    require_relative 'core/authenticator'
    require_relative 'core/plugin_installer'
    require_relative 'util/settings'

    include Bot::Core::ObjectLoader
    include Bot::Util::Settings

    attr_reader :adapters, :plugins, :s, :shared_db, :auth
    START_TIME = Time.now

    def initialize(bot_settings_path)
      Bot.const_set('ROOT_DIR',     File.join(Dir.pwd, 'lib'))
      Bot.const_set('SETTINGS_DIR', File.join(Dir.pwd, 'lib', 'settings'))
      Bot.const_set('DATABASE_DIR', File.join(Dir.pwd, 'lib', 'databases'))

      @s = nil
      @settings_path = bot_settings_path
      load_settings

      Bot.const_set('SHORT_TRIGGER', @s[:short_trigger])
      @authenticator = Bot::Core::Authenticator.new

      @shared_db = Bot::Database.new(File.join(Bot::DATABASE_DIR, 'shared.sqlite3')) if @s[:databases][:shared_db]

      if @s[:webserver][:enabled]
        Bot.log.info('Web server enabled, starting...')
        require_relative 'webserver.rb'
        start_web(@s[:webserver])

        # Add (example) default path
        Web.get '/' do
          redirect '/index.html'
        end
      end

      initialize_objects(:adapter)
      initialize_objects(:plugin)
      initialize_objects(:external_plugin)
      Bot.log.info "#{@adapters.length} adapter(s) and #{@plugins.length} plugin(s) loaded."
      @s[:adapters][:autostart].each { |regex| start_adapters(regex) }
    end

    def initialize_objects(type)
      mode = @s["#{type}s".to_sym][:load_mode]

      if type == :adapter || type.nil?
        @adapters = {}
        load_objects(:adapter, mode)
      end

      # rubocop:disable Style/GuardClause
      if type == :plugin || type == :external_plugin || type.nil?
        @plugins = {}
        @plugin_mapping = {}
        @subscribed_plugins = []
        load_objects(:plugin, mode)
        load_objects(:external_plugin, mode)
      end
      # rubocop:enable Style/GuardClause
    end

    def start_adapters(regex = '.*')
      send_to_objects(@adapters, :connect, regex)
    end

    def stop_adapters(regex = '.*')
      send_to_objects(@adapters, :shutdown, regex)
    end

    def send_to_objects(list, method, regex = '.*')
      selected = list.select { |k, _| k.to_s.match(/#{regex}/i) }
      selected.each { |_, v| v.send(method) }
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    # rubocop:disable Metrics/MethodLength
    def core_triggers(trigger, m)
      if auth(5, m)
        case trigger
        when 'shutdown'
          shutdown
        when 'restart'
          restart
        when 'reload'
          reload(:plugin)
          reload(:external_plugin)
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
        # TODO: Blacklist external plugins
        when 'blacklist'
          m.reply 'Adapters: ' + @s[:adapters][:blacklist].join(', ')
          m.reply 'Plugins: ' + @s[:plugins][:blacklist].join(', ')
        when 'install'
          installed = plugin_install(m.args[0], m)

          if installed
            reload(:external_plugin)
            m.reply 'Reloaded.' if m.respond_to? :reply
          end
        when 'remove'
          removed = plugin_remove(m.args[0], m)

          if removed
            reload(:external_plugin)
            m.reply 'Reloaded.' if m.respond_to? :reply
          end
        when 'update'
          updated = plugin_update(m.args[0], 'master', m)

          if updated
            reload(:external_plugin)
            m.reply 'Reloaded.' if m.respond_to? :reply
          end
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
        if @plugin_mapping.key?(query)
          m.reply @plugin_mapping[query][:help]
        else
          m.reply "Use help <trigger> for details. Triggers: #{@plugin_mapping.keys.join(', ')}"
        end
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/MethodLength

    def blacklist(type, name)
      @s["#{type}s".to_sym][:blacklist].push(name).uniq!
      save_settings
    end

    def unblacklist(type, name)
      @s["#{type}s".to_sym][:blacklist].delete(name)
      save_settings
    end

    def trigger_plugin(trigger, m)
      unless core_triggers(trigger, m)
        # Check if plugin responds to trigger after core triggers
        if @plugin_mapping.key?(trigger.to_sym)
          plugin = @plugin_mapping[trigger.to_sym][:plugin]
          method = @plugin_mapping[trigger.to_sym][:method]
          required_auth_level = @plugin_mapping[trigger.to_sym][:required_auth_level]

          if @plugins.key?(plugin) && auth(required_auth_level, m)
            begin
              @plugins[plugin].send(method.to_sym, m)
            rescue StandardError => e
              Bot.log.error "#{plugin} ##{method} - #{e}\n#{e.backtrace.join("\n")}}"
            end
          end
        end
      end

      nil
    end

    def publish(m)
      # Plugin listens in to all messages
      @subscribed_plugins.each { |p| @plugins[p].receive(m) }
    end

    def register_trigger(trigger, plugin, method, required_auth_level, help = 'No help.')
      @plugin_mapping[trigger.to_sym] = {
        plugin: plugin.to_sym,
        method: method.to_sym,
        required_auth_level: required_auth_level.to_i,
        help: help
      }
    end

    def unregister_trigger(trigger)
      @plugin_mapping.delete(trigger.to_sym)
    end

    def subscribe_plugin(plugin)
      Bot.log.info "Subscribing plugin #{plugin}"
      @subscribed_plugins.push(plugin.to_sym)
    end

    def auth(level, m)
      @authenticator.auth(level, m)
    end

    def reload(type, name = nil)
      load_settings

      if type.nil?
        @adapters = nil
        @plugins = nil
        initialize_objects(:adapter)
        initialize_objects(:plugin)
        initialize_objects(:external_plugin)
      elsif name.nil?
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
        Web.quit!
        EM.stop
      end
    end
  end
end
