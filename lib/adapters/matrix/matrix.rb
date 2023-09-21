require 'matrix_sdk'

class Bot::Adapter::Matrix < Bot::Adapter
  attr_accessor :handler

  def initialize(bot)
    require_relative 'message'

    @s = {
      username: 'username',
      password: 'password',
      server: 'https://localhost.server',
      rooms: []
    }

    super
  end

  def connect
    Bot.log.info "#{self.class.name}: logging in as #{@s[:username]} to #{@s[:server]}..."
    @client = MatrixSdk::Client.new @s[:server]
    @client.login @s[:username], @s[:password]
    Bot.log.info "#{self.class.name}: logged in as #{@s[:username]}. whoami? #{@client.api.whoami?}."
    Bot.log.info "#{self.class.name}: in #{@client.rooms.count} rooms."

    @handler = @client

    @s[:rooms].each { |id|
      Bot.log.info "#{self.class.name}: joining room #{id}..."
      room = @client.join_room(id)
      Bot.log.info "#{self.class.name}: room joined: #{room.inspect}"
      room.on_event.add_handler { |ev|
        Bot.log.info "#{self.class.name}: ev #{ev}"
        m = to_adapter_message(room, ev)
        Bot.log.info "#{self.class.name}: m #{m}"
      }
      room.send_text "hello"
    }

    @client.start_listener_thread
  end

  def prepare_message(discord_addr)
    Bot.log.error("#{self.class.name}: prepare_message not implemented; tried parsing #{discord_addr}")
  end

  def message(channel, text)
    @client.message(channel:, text:)
  end

  def to_adapter_message(room, ev)
    Bot::Adapter::Matrix::Message.new do |m|
      m.channel  = ev.room_id
      m.client   = @client
      m.data     = ev
      m.hostname = nil
      m.origin   = self
      m.text     = ev.content.body
      m.user     = ev.sender
      m.room     = room
      m.msgtype  = ev.content.msgtype
    end
  end
end
