class Bot::Plugin::Pick < Bot::Plugin
  def initialize(bot)
    @s = {
      trigger: {
        pick: [:pick, 0, 'pick [n=1] item1 item2 item3'],
        shuffle: [:shuffle, 0, 'shuffle item1 item2 item3'],
        dice: [:dice, 0, 'dice [n=6]']
      },
      subscribe: false
    }
    super(bot)
  end

  def pick(m)
    picks = (/[0-9]+/ === m.args[0]) ? m.args[0].to_i : 1
    m.reply m.args[1..-1].sample(picks).join(', ')
  end

  def shuffle(m)
    m.reply m.args.shuffle.join(', ')
  end

  def dice(m)
    sides = m.args.length > 0 ? m.args[0].to_i : 6
    m.reply Random.rand(sides)
  end
end