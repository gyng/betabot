class Bot::Plugin::Info < Bot::Plugin
  def initialize(bot)
    @s = {
      trigger: {
        info: [:info, 5, 'betabot memory usage']
      },
      subscribe: false
    }
    super(bot)
  end

  def info(m=nil)
    bytes = `ps -o rss -p #{Process.pid}`.strip.split.last.to_i * 1024
    t = Process.times
    m.reply "PID #{Process.pid}, resident set size: #{bytes / 1024 / 1024}MB, user #{t.utime}s sys #{t.stime}s"
    m.reply "GC #{GC.stat}"
  end

  def receive(m)
  end
end
