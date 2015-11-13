require 'timeout'

class Bot::Plugin::Wserver < Bot::Plugin
  def initialize(bot)
    @s = {
      trigger: { wserver: [:wserver, 0, 'wserver <url>. Detects server software from its HTTP header.'] },
      subscribe: false
    }
    super(bot)
  end

  def wserver(m)
    Thread.new do
      Timeout::timeout(10) do
        host = m.args[0]
        http = Net::HTTP.new(host)
        http.read_timeout = 20
        res = http.head("/")

        case res.class
        when Net::HTTPRedirection, Net::HTTPMovedPermanently
          rs = "#{host} redirects to #{res['location']} (#{res.code} #{res.message} - #{res['server']})"
        else
          rs = "#{host} (#{res.code} #{res.message} - #{res['server']})"
        end

        m.reply rs
      end
    end
  end
end
