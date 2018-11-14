require 'slack-ruby-client'

class Bot::Adapter::Slack < Bot::Adapter
  attr_accessor :handler

  def initialize(bot)
    require_relative 'message'

    @s = {
      api_token: 'insert token here'
    }

    @reconnect_delay = 30

    # Avoid massive spam
    @slack_logger = ::Logger.new(STDOUT)
    @slack_logger.level = Logger::INFO

    super
  end

  def connect
    @client = ::Slack::RealTime::Client.new(token: @s[:api_token], logger: @slack_logger)
    @handler = @client

    @client.on :message do |data|
      Bot.log.info "#{self.class.name} #{@s[:name]}\n\t#{'<-'.cyan} #{data}"

      next if data.nil?

      m = to_adapter_message(data)

      if m.text =~ /^#{Bot::SHORT_TRIGGER}([^ ]*)/i || # !command
         m.text =~ /^#{@client.self.name}: ([^ ]*)/i || # BotNick: command
         m.text =~ /^<@#{@client.self.id}> ([^ ]*)/i # @BotNick hello (Slack)
        trigger = Regexp.last_match[1]
        trigger_plugin(trigger, m)
      end

      publish(m)
    end

    @client.on :closed do |_data|
      if !($shutdown || !$restart)
        Bot.log.warn "#{self.class.name} Connection closed: unexpected; reconnecting in #{@reconnect_delay} seconds..."
        EM.add_timer(@reconnect_delay) { @client.start! }
      else
        Bot.log.info "#{self.class.name} Connection closed"
      end
    end

    @client.on :hello do |_data|
      Bot.log.info "#{self.class.name} Connection established"
    end

    @client.start!
  end

  def message(channel, text)
    @client.message(channel: channel, text: text)
  end

  def to_adapter_message(slack_data)
    Bot::Adapter::Slack::Message.new do |m|
      m.channel  = slack_data.channel
      m.client   = @client
      m.data     = slack_data
      m.hostname = slack_data.user
      m.origin   = self
      m.text     = ::Slack::Messages::Formatting.unescape(slack_data.text || '')
      m.user     = slack_data.user
    end
  end

  def trigger_plugin(trigger, m)
    super(trigger, m)
  end
end
