class Bot::Plugin::Mpcsync::SyncListener < EventMachine::Connection
  require 'net/http'

  def initialize(plugin, m)
    @plugin = plugin
    @m = m
  end

  def receive_data(data)
    puts data
    puts data == 'GO!'

    if data == 'GO!'
      Net::HTTP.post_form(URI.parse(@plugin.command_addr), wm_command: '887')
      @m.reply 'Going.'
      @plugin.decock
      close_connection
    end
  rescue Exception => e
    puts e
  end

  def unbind
    puts 'close sync'
    @plugin.cock_state = :uncocked
  end
end