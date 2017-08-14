require 'tzinfo'

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
          'remind <user|me> to|about|of <subject> on|at|in <human time> ' \
          '[+-<hours_offset=0>|<2-letter country code|timezone identifier] ' \
          'Sets a reminder about something. Eg. '\
          '`remind me to eat pizza at tomorrow 7pm +8`, ' \
          'remind betabot about cat food at 0500 US/Pacific, ' \
          '`remind me of dog food on tuesday SG`. ' \
          'Timers are cleared when the bot is restarted. ' \
          'List of timezones and country codes: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones'
        ],
        timer: [
          :timer, 0,
          'timer <human time> ' \
          'Sets a timer. Eg. `timer 3 min`. ' \
          'Timers are cleared when the bot is restarted.'
        ]
      },
      subscribe: false
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

  # The logic is messy as we support multiple TZ declaration formats
  # while needing to hack around Chronic parsing quirks.
  def remind(m)
    victim = m.args[0] == 'me' ? m.sender : m.args[0]
    tokens = m.text.match(/^.+(to|about|of)(.+)(on .+|at .+|in .+)([\+\-].*)?$/)

    if !tokens.nil? && tokens.length < 3
      m.reply 'Syntax error: could not parse reminder'
      m.reply @s[:remind][2]
      return
    end

    subject = tokens[2].strip
    time_s = tokens[3].strip

    # Let tz be either an exact match for a zone identifier
    tz = get_timezone_from_zone_identifier(m.args.last)
    # An exact match from a country code with only one timezone
    tz = get_timezone_from_country_code(m, m.args.last) if tz.nil?
    # Abort if the country has multiple timezones
    return if tz == :ambiguous
    # Or a user-specified numeric timezone offset eg. +8
    tz = get_numeric_timezone_offset(m, m.args.last) if tz.nil? # defaults to 0

    time = parse_time(time_s, tz)

    if !time
      m.reply "Could not parse time \"#{time_s}\""
      return
    end

    remind_at = tz.is_a?(TZInfo::Timezone) ? tz.local_to_utc(time) : add_numeric_tz_offset(time, tz)
    seconds_to_trigger = remind_at - Time.now

    if seconds_to_trigger < 0
      m.reply 'I cannot travel back in time!'
      return
    end

    EventMachine.add_timer(seconds_to_trigger) do
      hours_ago = (seconds_to_trigger / 60.0 / 60.0).round(1)
      m.reply("🔔 -#{hours_ago}h #{m.sender} > #{victim}: #{subject}")
    end

    m.reply "Reminder parsed using timezone #{tz} set for #{remind_at}."
  end

  private

  def parse_time(time_s, tz)
    # Required Chronic hack.
    Time.use_zone('UTC') do
      now = if tz.is_a?(TZInfo::Timezone)
              tz.utc_to_local(Time.now.utc)
            elsif tz.is_a?(Numeric)
              Time.now.utc.change(offset: tz)
            else
              Time.now.utc
            end
      time_s = time_s.gsub(/^at /, '') # Chronic cannot parse "at 10pm tomorrow"
      parsed = Chronic.parse(time_s, now: now)

      # Try to parse without last argument as it could be a tz
      if parsed.nil?
        time_s = time_s.split(' ')[0...-1].join(' ')
        parsed = Chronic.parse(time_s, now: now)
      end

      parsed
    end
  end

  def add_numeric_tz_offset(time, tz_offset)
    time - tz_offset * 60 * 60
  end

  def get_numeric_timezone_offset(m, arg)
    tz_offset_matches = arg.match(/^([\+\-].*)$/)
    # defaults to UTC
    if !tz_offset_matches.nil? && !tz_offset_matches[1].nil?
      offset_s = tz_offset_matches[1]
      return offset_s.to_i
    end

    m.reply 'Unspecified or unknown timezone: defaulting to UTC.'
    0
  end

  def get_timezone_from_zone_identifier(id)
    TZInfo::Timezone.get(id)
  rescue StandardError
    Bot.log.info "Remind: Could not get timezone from zone identifier for #{id}"
    nil
  end

  def get_timezone_from_country_code(m, cc)
    zones = TZInfo::Country.get(cc).zone_identifiers

    return TZInfo::Timezone.get(zones[0]) if zones.length == 1

    if zones.length > 1
      m.reply "Multiple zone identifiers available for #{cc}, use one of these: #{zones.join(', ')}"
      return :ambiguous
    end

    nil
  rescue StandardError
    Bot.log.info "Remind: Could not get timezone from country code for #{cc}"
    nil
  end
end
