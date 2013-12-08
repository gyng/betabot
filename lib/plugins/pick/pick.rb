class Bot::Plugin::Pick < Bot::Plugin
  def initialize(bot)
    @s = {
      trigger: { pick: [:pick, 0], pick_one: [:pick_one, 0], shuffle: [:shuffle, 0] },
      subscribe: false,
      help: 'Picks or shuffles items for you.'
    }
    super(bot)
  end

  def pick_one(m)
    m.reply m.args.sample
  end

  def pick(m)
    m.reply m.args[1..-1].sample(m.args[0].to_i).join(', ')
  end

  def shuffle(m)
    m.reply m.args.shuffle.join(', ')
  end
end