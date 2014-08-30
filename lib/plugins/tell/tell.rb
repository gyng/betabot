class Bot::Plugin::Tell < Bot::Plugin
  def initialize(bot)
    @s = {
      trigger: { tell: [:tell, 0, 'tell <user> <message> Tells a user some message when the user is next seen by the bot.'] },
      subscribe: true
    }

    @stored_messages = {}

    super(bot)
  end

  def tell(m)
    @stored_messages[m.args[0]] = { message: m.args[1], from: m.sender }
    m.reply("Okay!")
  end

  def receive(m)
    tell = @stored_messages.delete(m.sender)
    m.reply("#{m.sender}: #{tell[:from]} wanted to tell you ``#{tell[:message]}''") if !tell.nil?
  end
end
