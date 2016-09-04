class Bot::Plugin::Mpcsync::SyncListener < EventMachine::Connection
  require 'net/http'

  def initialize(plugin, m)
    @plugin = plugin
    @m = m
  end

  def receive_data(data)
    Bot.log.info "#{self.class.name} Received #{data}"

    if data == 'GO!'
      Net::HTTP.post_form(URI.parse(@plugin.command_addr), wm_command: '887')
      @m.reply 'Going.' if @m.respond_to?(:reply)
      @plugin.decock
      close_connection
    end
  rescue StandardError => e
    Bot.log.error "#{self.class.name} #{e}"
  end

  def unbind
    Bot.log.info "#{self.class.name} Unbinding sync listen..."
    @plugin.cock_state = :uncocked
  end
end
