# Chronic can't do timezones at all!
module Chronic
  def self.time_class
    ::Time.zone
  end
end

class Bot::Plugin::Remind < Bot::Plugin
  def initialize(bot)
    @s = {
      trigger: {
        remind: [
          :remind, 0,
          'remind <user|me> to|about|of <subject> on|at|in <human time> [+-<hours_offset=0>] ' \
          'Sets a reminder about something. Eg. `remind me to eat pizza at tomorrow 7pm +8`. ' \
          'Timers are cleared when the bot is restarted.'
        ],
        timer: [
          :timer, 0,
          'timer <human time> ' \
          'Sets a timer. Eg. `timer 3min`. ' \
          'Timers are cleared when the bot is restarted.'
        ]
      },
      subscribe: true
    }

    super(bot)
  end

  def timer(m)
    time_s = "in #{m.args.join(' ')}"

    time = Time.use_zone('UTC') do
      Chronic.parse(time_s, now: Time.now.utc)
    end

    if time.nil?
      m.reply "Could not parse \"#{time_s}\""
      return
    end

    seconds_to_trigger = time - Time.now

    if seconds_to_trigger < 0
      m.reply 'I cannot travel back in time!'
      return
    end

    EventMachine.add_timer(seconds_to_trigger) do
      min_ago = (seconds_to_trigger / 60.0).round(1)
      m.reply("🕛 -#{min_ago}m #{m.sender}")
    end

    m.reply "Timer set for #{time}."
  end

  def remind(m)
    victim = m.args[0] == 'me' ? m.sender : m.args[0]
    tokens = m.text.match(/^.+(to|about|of)(.+)(on .+|at .+|in .+)([\+\-].*)?$/)

    if !tokens.nil? && tokens.length < 3
      m.reply 'Syntax error: could not parse reminder'
      return
    end

    subject = tokens[2].strip
    time_s = tokens[3].strip

    tz_matches = m.args.last.match(/^([\+\-].*)$/)
    # defaults to UTC
    tz_offset = if !tz_matches.nil? && !tz_matches[1].nil?
                  offset_s = tz_matches[1]
                  time_s = time_s.split(' ')[0...-1].join(' ')
                  offset_s.to_i
                else
                  0
                end

    time = Time.use_zone('UTC') do
      time_s = time_s.gsub(/^at /, '') # Chronic cannot parse "at 10pm tomorrow"
      Chronic.parse(time_s, now: Time.now.utc)
    end

    if !time
      m.reply "Could not parse time \"#{time_s}\""
      return
    end

    time_with_offset = time - tz_offset * 60 * 60
    seconds_to_trigger = time_with_offset - Time.now

    if seconds_to_trigger < 0
      m.reply 'I cannot travel back in time!'
      return
    end

    EventMachine.add_timer(seconds_to_trigger) do
      hours_ago = (seconds_to_trigger / 60.0 / 60.0).round(1)
      m.reply("🔔 -#{hours_ago}h #{m.sender} > #{victim}: #{subject}")
    end

    m.reply "Reminder set for #{time_with_offset}."
  end
end
