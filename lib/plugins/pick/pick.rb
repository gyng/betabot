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
    picks_arg = m.args[0] =~ /[0-9]+/
    picks = picks_arg ? m.args[0].to_i : 1
    picks = picks > 2_147_483_647 ? 2_147_483_647 : picks
    starting_index = numeric?(picks_arg) ? 1 : 0
    m.reply m.args[starting_index..].join(' ').split(',').sample(picks).map(&:strip).join(', ')
  end

  def shuffle(m)
    m.reply m.args.join(' ').split(',').shuffle.map(&:strip).join(', ')
  end

  def dice(m)
    sides = !m.args.empty? ? m.args[0].to_i : 6
    m.reply Random.rand(sides)
  end

  def numeric?(obj)
    obj.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/).nil? ? false : true
  end
end
