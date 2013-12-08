class Bot::Plugin::Pick < Bot::Plugin
  def initialize(bot)
    @s = {
      trigger: {
        pick: [:pick, 0, 'pick <n> item1 item2 item3'],
        pick_one: [:pick_one, 0, 'pick_one item1 item2 item3'],
        shuffle: [:shuffle, 0, 'shuffle item1 item2 item3'],
        dice: [:dice, 0, 'dice [n=6]']
      },
      subscribe: false
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

  def dice(m)
    sides = m.args.length > 0 ? m.args[0].to_i : 6
    m.reply Random.rand(sides)
  end
end