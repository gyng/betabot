module Bot
  require 'json'
  require 'date'
  require 'logger'
  require 'timeout'

  require_relative 'adapter'
  require_relative 'plugin'
  require_relative 'util/logger'

  # rubocop:disable Metrics/ClassLength
  class Core
    require_relative 'database'
    require_relative 'core/message'
    require_relative 'core/object_loader'
    require_relative 'core/authenticator'
    require_relative 'core/plugin_installer'
    require_relative 'util/settings'

    include Bot::Core::ObjectLoader
    include Bot::Util::Settings

    attr_reader :adapters, :plugins, :s, :shared_db

    START_TIME = Time.now

    def initialize(bot_settings_path)
      Bot.const_set('ROOT_DIR',     File.join(Dir.pwd, 'lib')) unless Bot.const_defined?('ROOT_DIR')
      Bot.const_set('SETTINGS_DIR', File.join(Dir.pwd, 'lib', 'settings')) unless Bot.const_defined?('SETTINGS_DIR')
      Bot.const_set('DATABASE_DIR', File.join(Dir.pwd, 'lib', 'databases')) unless Bot.const_defined?('DATABASE_DIR')

      @s = nil
      @settings_path = bot_settings_path
      load_settings

      Bot.const_set('SHORT_TRIGGER', @s[:short_trigger]) unless Bot.const_defined?('SHORT_TRIGGER')
      @authenticator = Bot::Core::Authenticator.new

      @shared_db = Bot::Database.new(File.join(Bot::DATABASE_DIR, 'shared.sqlite3')) if @s[:databases][:shared_db]

      if @s[:webserver][:enabled]
        Bot.log.info('Web server enabled, starting...')
        require_relative 'webserver'
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
      check_external_plugins if @s[:external_plugins][:check_after_startup]
    end

    def check_external_plugins
      Bot.log.info 'Checking updates for external plugins...'
      Thread.new do
        reload_needed = false

        @s[:external_plugins][:include].each do |plugin_config|
          manifest_url = plugin_config[:manifest]
          Bot.log.info "Getting manifest at #{manifest_url}..."
          manifest = get_manifest(manifest_url)
          Bot.log.info "Parsed manifest at #{manifest_url}: #{manifest.inspect}"
          reload_needed ||= plugin_install(manifest)
        end

        if reload_needed
          reload(:external_plugin)
          Bot.log.info 'Plugins updated. Bot reloaded.'
        else
          Bot.log.info 'No updates to external plugins.'
        end
      end.join
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

    def core_install_plugin(m)
      url = m.args[0]
      Bot.log.info "Getting manifest at #{url}..."
      manifest = get_manifest(url)
      Bot.log.info "Parsed manifest at #{url}: #{manifest.inspect}"
      installed = plugin_install(manifest, true, m)

      return if !installed

      reload(:external_plugin)
      m.reply 'Reloaded.' if m.respond_to? :reply

      return if m.args[1] != 'save'

      config = {
        name: manifest[:name],
        manifest: url,
        git: manifest[:git]
      }
      @s[:external_plugins][:include].push(config).uniq!
      save_settings
      m.reply 'Configuration saved.'
    end

    def core_remove_plugin(m)
      name = m.args[0]
      removed = plugin_remove(name, m)

      return if !removed

      reload(:external_plugin)
      m.reply 'Reloaded.' if m.respond_to? :reply

      return if m.args[1] != 'save'

      config = @s[:external_plugins][:include].find { |c| c[:name] == name }
      if config
        deleted = @s[:external_plugins][:include].delete(config)
        save_settings if deleted
        m.reply "Configuration was #{deleted ? '' : 'not '}saved."
      else
        m.reply 'Plugin was not in startup plugin check list.'
      end
    end

    def core_update_plugin(m)
      name = m.args[0]
      updated = plugin_update(name, 'master', m)

      return if !updated

      reload(:external_plugin)
      m.reply 'Reloaded.' if m.respond_to? :reply
    end

    def reset_plugin(m)
      name = m.args[0]
      path = File.join('lib', 'settings', 'plugins', "#{name.downcase}.json")

      if File.file?(path)
        File.rename(path, "#{path}.bak")
        m.reply "Settings for #{name} have been reset."
      else
        m.reply "Settings file for #{name} was not found."
      end
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
          # Fix: check auth levels
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
          m.reply "Adapters: #{@s[:adapters][:blacklist].join(', ')}"
          m.reply "Plugins: #{@s[:plugins][:blacklist].join(', ')}"
          m.reply "Users: #{@s[:users][:blacklist].join(', ')}"
          m.reply "Content: #{@s[:contents][:blacklist].join(', ')}"
        when 'blacklist_user'
          blacklist(:user, m.args[0])
          m.reply "Ignoring user #{m.args[0]}."
        when 'unblacklist_user'
          unblacklist(:user, m.args[0])
          m.reply "User #{m.args[0]} unblacklisted."
        when 'blacklist_content'
          blacklist(:content, m.args[0])
          m.reply "Ignoring content #{m.args[0]}."
        when 'unblacklist_content'
          unblacklist(:content, m.args[0])
          m.reply "Content #{m.args[0]} unblacklisted."
        when 'install'
          core_install_plugin(m)
        when 'remove'
          core_remove_plugin(m)
        when 'update'
          core_update_plugin(m)
        when 'plugin_check_list'
          checking = @s[:external_plugins][:check_after_startup]
          list = @s[:external_plugins][:include].inspect
          m.reply "Checking on startup: #{checking}, #{list}"
        when 'reset_plugin'
          reset_plugin(m)
        when 'version'
          m.reply $version
        else
          false
        end
      end

      core_triggers_help = {
        'shutdown' => 'Shuts the bot down.',
        'restart' => 'Restarts the bot.',
        'reload' => 'Reloads all plugins, including external plugins',
        'useradd' => 'useradd <user> <pass> <level 0-5>, 5 being admin',
        'blacklist_adapter' => 'blacklist_adapter <adapter>',
        'unblacklist_adapter' => 'unblacklist_adapter <adapter>',
        'blacklist_plugin' => 'blacklist_plugin <plugin>',
        'unblacklist_plugin' => 'unblacklist_plugin <plugin>',
        'blacklist_user' => 'blacklist_user <user_regex>',
        'unblacklist_user' => 'unblacklist_user <user_regex>',
        'blacklist_content' => 'blacklist_content <content_regex>',
        'unblacklist_content' => 'unblacklist_content <content_regex>',
        'install' => 'install <external_plugin_manifest_url> (save) Save will add it to bot_settings.',
        'update' => 'update <plugin_name> Updates an external plugin.',
        'remove' => 'remove <plugin_name> Removes an external plugin.',
        'plugin_check_list' => 'plugin_check_list Shows a list of installed and saved plugins.',
        'reset_plugin' => 'reset_plugin <name> Resets a plugin\'s settings to the defaults.',
        'version' => 'version Shows the current version.'
      }

      case trigger
      when 'login'
        @authenticator.login(m)
      when 'logout'
        @authenticator.logout(m)
      when 'help'
        if m.args[0] == 'core'
          query = m.args[1]
          if core_triggers_help.key?(query)
            m.reply core_triggers_help[query]
          else
            msg = [
              "#{'Core triggers'.blue}: #{core_triggers_help.keys.join(', ')}.",
              'Use help core <trigger> for details.'
            ].join(' ')
            m.reply msg
          end
        else
          query = m.args[0].to_sym if m.args[0].is_a?(String)
          if @plugin_mapping.key?(query)
            m.reply @plugin_mapping[query][:help]
          else
            msg = [
              "#{'Plugin triggers'.green}: #{@plugin_mapping.keys.join(', ')}.",
              'Use help <trigger> for details. Use help core for core triggers.'
            ].join(' ')
            m.reply msg
          end
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

    def blacklisted?(type, value)
      # Very inefficient, but way less code to write
      regices = @s["#{type}s".to_sym][:blacklist].map { |str| Regexp.compile(str) }
      regices.each do |re|
        if re.match(value)
          Bot.log.info("Bot::Core - Blacklist check for #{type} returned false for value #{value}")
          return true
        end
      end

      false
    rescue StandardError => e
      Bot.log.warn("Bot::Core - Blacklist check error: #{e}")
      false
    end

    def trigger_plugin(trigger, m)
      unless core_triggers(trigger, m)
        # Check if plugin responds to trigger after core triggers
        return :blacklist if blacklisted?(:user, m.hostname) ||
                             blacklisted?(:user, m.sender) ||
                             blacklisted?(:user, m.real_name)
        return :blacklist if blacklisted?(:content, m.text)

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
      return :blacklist if blacklisted?(:user, m.hostname) ||
                           blacklisted?(:user, m.sender) ||
                           blacklisted?(:user, m.real_name)
      return :blacklist if blacklisted?(:content, m.text)

      # Plugin listens in to all other messages
      @subscribed_plugins.each { |p| @plugins[p].receive(m) }
    end

    def register_trigger(trigger, plugin, method, required_auth_level, help = 'No help.')
      @plugin_mapping[trigger.to_sym] = {
        plugin: plugin.to_sym,
        method: method.to_sym,
        required_auth_level: required_auth_level.to_i,
        help:
      }
    end

    def unregister_trigger(trigger)
      @plugin_mapping.delete(trigger.to_sym)
    end

    def subscribe_plugin(plugin)
      Bot.log.info "Subscribing plugin #{plugin}"
      @subscribed_plugins.push(plugin.to_sym)
    end

    def on_connect(adapter, conn)
      @plugins.each { |_, v| v.on_connect(adapter, conn) if defined? v.on_connect }
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
        Web.quit! if defined?(Web)
        EM.stop
      end
    end

    def address_str(str)
      combo = str.split(':::')

      if combo.length != 2
        Bot.log.error("Core: Bad address #{str}, called by #{caller}")
        return nil
      end

      address(combo[0].to_sym, combo[1])
    end

    def address(protocol, addr)
      adapter = @adapters[protocol]

      if adapter
        adapter.prepare_message(addr)
      else
        Bot.log.error("Core: Bad protocol #{protocol}; could not find adapter")
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
