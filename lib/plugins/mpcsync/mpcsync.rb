class Bot::Plugin::Mpcsync < Bot::Plugin
  attr_reader :ui_addr, :command_addr, :control_addr
  attr_accessor :cock_state

  require 'socket'
  require_relative 'synclistener'
  # require_relative 'syncsender'

  def initialize(bot)
    @s = {
      trigger: {
        mpcsync: [:call, 0],
        cock: [:cock, 5],
        decock: [:decock, 5],
        np: [:now_playing, 5],
        sync: [:sync, 0]
      },
      subscribe: false,
      help: 'Mpcsync is a synchronization client and server for Media Player Classic.',

      web_ui_addr: 'http://localhost:13579',
      sync_listen_port: 15555,
      sync_countdown: 3,
      sync_subscribers: [
        ['127.0.0.1', 15555] # Add self as a subscriber for !sync
      ]
    }

    @ui_addr      = @s[:web_ui_addr]
    @command_addr = @ui_addr + '/command.html'
    @control_addr = @ui_addr + '/controls.html'
    @cock_state   = :uncocked
    @listen_sock  = nil

    super(bot)
  end

  # The method called is defined in @s[:trigger]. In this case, it's #call.
  def call(m)
    puts m.args
    case m.mode
    when 'subscribe'
      if auth_r(4, m)
        add_sync_subscriber(m.args[1], m.args[2])
        m.reply "Added subscriber #{m.args[1]}:#{m.args[2]}"
      end
    when 'unsubscribe'
      if auth_r(4, m)
        del_sync_subscriber(m.args[1], m.args[2])
        m.reply "Deleted subscriber #{m.args[1]}:#{m.args[2]}"
      end
    when 'list'
      m.reply @s[:sync_subscribers].map { |sub| "#{sub[0]}:#{sub[1]}"}.join(', ')
    end
  end

  def cock(m)
    if @cock_state != :cocked
      @listen_sock ||= EM.open_datagram_socket('0.0.0.0', @s[:sync_listen_port], SyncListener, self, m)
      @cock_state = :cocked
    end

    m.reply "Cocked. #{now_playing}"
  end

  def decock(m=nil)
    @listen_sock.close_connection if @listen_sock
    @cock_state = :uncocked
    m.reply 'Decocked.'
  end

  def now_playing(m=nil)
    doc      = Nokogiri::HTML(open(@control_addr))
    filepath = doc.search('//td[@colspan="4"]/a[1]').inner_text
    filename = filepath.to_s.split('\\').last
    cur_time = doc.search('//td[@id="time"]').inner_text
    length   = doc.search('//td[@id="time"]/../td[3]').inner_text
    status   = doc.xpath('//td[@colspan="4"]/../../tr[2]/td[1]').inner_text.gsub(/(\W|Status)/, '')

    now_playing = "#{status}: #{filename} [#{cur_time}/#{length}]"
    m.reply now_playing if m.respond_to?(:reply)
    now_playing
  end

  def add_sync_subscriber(addr, port)
    if addr.is_a?(String) && port.to_i.is_a?(Fixnum)
      @s[:sync_subscribers].push([addr, port.to_i]).uniq!
      save_settings
    end
  end

  def del_sync_subscriber(addr, port)
    @s[:sync_subscribers].delete([addr, port.to_i])
    save_settings
  end

  def sync(m)
    remaining = @s[:sync_countdown]

    countdown = EventMachine.add_periodic_timer(1) do
      m.reply remaining
      if (remaining -= 1) <= 0
        m.reply 'GO!'
        # Forget about using EM.open_datagram_socket for this simple task
        @s[:sync_subscribers].each { |s| UDPSocket.open.send("GO!", 0, s[0], s[1].to_i) }
        countdown.cancel
      end
    end
  end
end