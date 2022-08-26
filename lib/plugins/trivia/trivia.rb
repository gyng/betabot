require 'cgi'

class Bot::Plugin::Trivia < Bot::Plugin
  def initialize(bot)
    @s = {
      trigger: {
        trivia: [
          :trivia, 0,
          'trivia [<type>] Gets a trivia question from opentdb.com. ' \
          'type = {"", anime, games, computers, gadgets, science, sports, history, geography}'
        ],
        'trivia-stats' => [
          :stats, 0,
          'Gets trivia leaderboards'
        ]
      },
      subscribe: true
    }

    @active = {}
    @winners = {}
    @games = {}

    super(bot)
  end

  def trivia(m) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    if @active.key?(m.channel)
      m.reply "Trivia in progress in #{m.channel}!"
      return
    end

    seconds = 10

    url = 'https://opentdb.com/api.php?amount=1&encode=url3986'
    url += '&category=31' if m.mode == 'anime'
    url += '&category=18' if m.mode == 'computers'
    url += '&category=15' if m.mode == 'games'
    url += '&category=30' if m.mode == 'gadgets'
    url += '&category=17' if m.mode == 'science'
    url += '&category=21' if m.mode == 'sports'
    url += '&category=22' if m.mode == 'geography'
    url += '&category=23' if m.mode == 'history'

    res = RestClient.get(url)
    q = JSON.parse(res, symbolize_names: true)[:results][0]

    q.each do |k, v|
      case v
      when Array
        q[k] = v.map { |opt| CGI.unescape(opt).strip }
      when String
        q[k] = CGI.unescape(v).strip
      end
    end

    options = q[:incorrect_answers]
              .concat([q[:correct_answer]])
              .shuffle
              .map
              .with_index { |o, i| { key: (i + 1).to_s, option: o } }
    answer_key = options.find { |o| o[:option] == q[:correct_answer] }[:key]
    options_string = options.map { |o| "#{o[:key]}) #{o[:option]}" }.join(' · ')

    timer = EventMachine::Timer.new(seconds) do
      m.reply "Time's up! The answer was #{answer_key}) #{q[:correct_answer]}"
      @active.delete(m.channel)
    end

    @games[m.channel] = 0 if !@games.key?(m.channel)
    @games[m.channel] += 1

    @active[m.channel] = {
      time: Time.now,
      answer: q[:correct_answer],
      answer_key:,
      options:,
      timer:,
      answered: { m.hostname => -1 }
    }
    m.reply "⏲️ #{seconds}s #{q[:category]} – #{q[:question].bold}: #{options_string}"
  end

  def stats(m)
    channel = @winners[m.channel]

    if channel.nil?
      m.reply "No winners for #{m.channel}!"
      return
    end

    stats = channel.to_a
    m.reply "Rounds: #{@games[m.channel]}, " +
            stats.sort_by { |w| w[1][:wins] }.reverse.map { |w| "#{w[1][:name]}: #{w[1][:wins]}" }.join(', ')
  end

  def receive(m)
    return if !@active.key?(m.channel)

    if !@active[m.channel][:answered].key?(m.hostname)
      @active[m.channel][:answered][m.hostname] = 1
    else
      @active[m.channel][:answered][m.hostname] += 1
      return if @active[m.channel][:answered][m.hostname] > 1
    end

    return if @active[m.channel][:answer_key] != m.text

    m.reply "#{m.sender} won! The answer was #{@active[m.channel][:answer_key]}) #{@active[m.channel][:answer]}"
    @active[m.channel][:timer].cancel
    @active.delete(m.channel)
    @winners[m.channel] = {} if @winners[m.channel].nil?

    if @winners[m.channel][m.hostname].nil?
      @winners[m.channel][m.hostname] = { name: m.sender, wins: 1 }
    else
      @winners[m.channel][m.hostname][:wins] += 1
    end
  end
end
