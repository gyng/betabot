class Bot::Plugin::Script < Bot::Plugin
  require 'timeout'

  def initialize(bot)
    @s = {
      trigger: {
        script: [:script, 5, 'Evals the script in a binding with $SAFE = 2 and a timeout.'],
        macro: [:macro, 5, 'macro (add <trigger> <auth level> <script>|delete <trigger>|list)']
      },
      macros: {},
      subscribe: false,
      timeout: 3
    }
    super(bot)
    @s[:macros].each do |trigger, opts|
      begin
        register_trigger(trigger, opts)
      rescue Exception => e
        Bot.log.info "Failed to load macro #{trigger}: #{e}"
        next
      end
    end
  end

  def register_trigger(trigger, opts)
    self.class.send(:define_method, opts[0]) { |m| run_script(m, opts[2]) }
    @bot.register_trigger(trigger, @plugin_name, *opts)
  end

  def unregister_trigger(trigger)
    @bot.unregister_trigger(trigger)
  end

  def script(m)
    run_script(m, m.args.join(' '))
  end

  def macro(m)
    case m.mode
    when 'add'
      trigger = m.args[1].to_sym
      opts = [trigger, m.args[2], m.args[3..-1].join(' ')]
      @s[:macros][trigger] = opts
      register_trigger(trigger, opts)
      save_settings
      m.reply "#{trigger} added."
    when 'delete'
      trigger = m.args[1].to_sym
      if @s[:macros].delete(trigger)
        unregister_trigger(trigger)
        save_settings
        m.reply "#{trigger} deleted."
      else
        m.reply "#{trigger} not found."
      end
    when 'list'
      m.reply @s[:macros].keys.inspect
    else
      m.reply 'Unknown command.'
    end
  end

  def run_script(m, script)
    Thread.start do
      begin
        # Not entirelly safe. Ideally, we use JRuby's JVM.
        $SAFE = 2
        b = Context.new.get_binding
        Timeout::timeout(@s[:timeout]) { m.reply "=> #{b.eval(script).inspect}" }
      rescue Exception => e
        m.reply "=> #{e.inspect}"
      end
    end
  end

  class Bot::Plugin::Script::Context
    def get_binding
      return binding()
    end
  end
end
