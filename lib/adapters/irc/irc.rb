class Bot::Adapter::Irc < Bot::Adapter
  attr_accessor :latency

  def initialize
    require_relative 'message'
    require_relative 'handler'

    # temp variables for code stolen from HidoiBot
    @ssl = true
    @hostname = 'irc.yasashiisyndicate.org'
    @port = 6697
    @defaultNickname = 'WaruiBot'
    super
  end

  def connect
    EM.connect(@hostname, @port, Handler, self, @ssl)
  end
end