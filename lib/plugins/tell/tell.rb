class Bot::Plugin::Tell < Bot::Plugin
  def initialize(bot)
    @s = {
      trigger: { tell: [
        :tell, 0,
        'tell <user> <message> Tells a user some message when the user is next seen by the bot.'
      ] },
      subscribe: true
    }

    @stored_messages = {}

    super(bot)
  end

  def tell(m)
    @stored_messages[m.args[0]] = [] if @stored_messages[m.args[0]].nil?
    @stored_messages[m.args[0]].push(message: m.args[1..-1].join(' '), from: m.sender, at: Time.now.to_i)
    m.reply('Okay!')
  end

  def receive(m)
    case m.adapter
    when :irc
      if m.type == :privmsg || m.type == :join
        tells = @stored_messages.delete(m.sender)
        unless tells.nil?
          tells.each do |t|
            m.reply("#{m.sender}: #{t[:from]} wanted to tell you ``#{t[:message]}'', " \
                    "#{((Time.now.to_i - t[:at]) / 60.0 / 60.0).round(2)} hours ago")
          end
        end
      end
    end
  end
end
