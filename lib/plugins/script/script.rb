class Bot::Plugin::Script < Bot::Plugin
  require 'timeout'

  def initialize(bot)
    @s = {
      trigger: { script: [:call, 5, 'Evals the script in a binding with $SAFE = 2 and a timeout.'] },
      subscribe: false,
      timeout: 3
    }
    super(bot)
  end

  def call(m)
    Thread.start do
      begin
        # Not entirelly safe. Ideally, we use JRuby's JVM.
        $SAFE = 2
        b = Context.new.get_binding
        Timeout::timeout(@s[:timeout]) do
          m.reply "=> #{b.eval(m.args.join(' ')).inspect}"
        end
      rescue Exception => e
        m.reply e.inspect
      end
    end
  end

  class Bot::Plugin::Script::Context
    def get_binding
      return binding()
    end
  end
end