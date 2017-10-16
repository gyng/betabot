@client = ::Slack::RealTime::Client.new(token: @s[:api_token], logger: @slack_logger)

@client.on :message do |data|
  Bot.log.info "#{self.class.name} #{@s[:name]}\n\t#{'<-'.cyan} #{data}"

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
