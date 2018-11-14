require 'discordrb'

class Bot::Adapter::Discord < Bot::Adapter
  attr_accessor :handler

  def initialize(bot)
    require_relative 'message'

    @s = {
      api_token: 'insert token here',
      client_id: 'insert client id here'
    }

    @reconnect_delay = 30

    super
  end

  def connect
    @client = Discordrb::Bot.new token: @s[:api_token], client_id: @s[:client_id]
    @handler = @client

    @client.message do |data|
      Bot.log.info "#{self.class.name} #{@s[:client_id]}\n\t#{'<-'.cyan} #{data.message.inspect}"

      m = to_adapter_message(data)

      if m.text =~ /^#{Bot::SHORT_TRIGGER}([^ ]*)/i || # !command
         m.text =~ /^#{@client.profile.username}: ([^ ]*)/i || # BotNick: command
         m.text =~ /^<@#{@client.profile.id}> ([^ ]*)/i # @BotNick hello (Discord)
        trigger = Regexp.last_match[1]

        if ['invite', 'help'].include? trigger
          m.reply "Invite: https://discordapi.com/permissions.html#515136 client_id: #{@s[:client_id]}"
        end

        trigger_plugin(trigger, m)
      end

      publish(m)
    end

    @client.run
  end

  def message(channel, text)
    @client.message(channel: channel, text: text)
  end

  def to_adapter_message(data)
    Bot::Adapter::Discord::Message.new do |m|
      m.channel  = data.message.channel
      m.client   = @client
      m.data     = data
      m.hostname = data.message.author.id
      m.origin   = self
      m.text     = data.message.content
      m.user     = data.message.author.name
    end
  end

  def trigger_plugin(trigger, m)
    super(trigger, m)
  end
end
