require 'tzinfo'

# Chronic can't do timezones at all!
module Chronic
  def self.time_class
    ::Time.zone
  end
end

# rubocop:disable Metrics/ClassLength
class Bot::Plugin::Remind < Bot::Plugin
  def initialize(bot)
    @s = {
      trigger: {
        remind: [
          :remind, 0,
          'remind <user|me> to|about|of <subject> on|at|in <human time> ' \
          '<hours_offset|2-letter country code|timezone identifier search query> ' \
          'Sets a reminder about something. Eg. '\
          '`remind me to eat pizza at tomorrow 7pm +8`, ' \
          '`remind betabot about cat food at 0500 US/Pacific`, ' \
          '`remind world about no generics in golang in 5 minutes`, ' \
          '`remind me of dog food on tuesday jp`. Timers are cleared when the bot is restarted. ' \
          'If using `remind me in`, the timezone does not have to be specified. Search for a tz using ' \
          '`tz country sg` or `tz info asia` List of timezones and country codes: ' \
          'https://en.wikipedia.org/wiki/List_of_tz_database_time_zones'
        ],
        timer: [
          :timer, 0,
          'timer <human time> ' \
          'Sets a timer. Eg. `timer 3 min`. ' \
          'Timers are cleared when the bot is restarted.'
        ],
        tz: [
          :tz, 0,
          'tz country <2-letter country code>, ' \
          'tz info <tzid search query> '
        ]
      },
      subscribe: false
    }

    super(bot)
  end

  def tz(m)
    if m.args[1].nil?
      m.reply @s[:trigger][:tz][2]
      return
    end

    case m.mode
    when 'country'
      country_tzs(m)
    when 'info'
      tzinfo(m)
    when 'search'
      tzinfo(m)
    else
      m.reply @s[:trigger][:tz][2]
    end
  end

  def country_tzs(m)
    cc = m.args[1].upcase
    if cc.length != 2
      m.reply 'Use a 2-letter country code (eg. US, JP, DE, ES, SG).'
      return
    end

    begin
      zones = TZInfo::Country.get(cc).zone_identifiers
    rescue StandardError
      m.reply "#{cc} is not a country."
    end

    s = zones.join(', ')
    m.reply s
    s
  end

  # Finds [partial matches for zone identifiters] xor [an exact match]
  def find_zone(query)
    zones = TZInfo::Timezone.all

    matches = zones.find_all do |z|
      z.identifier.downcase.include?(query.downcase)
    end

    exact_match = matches.find do |z|
      z.identifier.downcase == query.downcase # rubocop:disable Performance/Casecmp
    end

    matches = [exact_match] if !exact_match.nil?
    matches
  end

  def tzinfo(m)
    query = m.args[1]
    matches = find_zone(query)

    reply = ''

    if matches.length == 1
      z = matches[0]
      period = z.current_period

      reply = "🌐 #{z.identifier}: #{z.strftime('%c %z').bold} (#{Time.now.utc})"
      reply += "🌄 #{period.offset.abbreviation} active" if period.dst?

      format_offset = lambda do |o|
        hours = o / 60 / 60
        prefix = if hours.zero? then '±'
                 elsif hours < 0 then '-'
                 elsif hours > 0 then '+'
                 end
        "#{prefix}#{hours}h"
      end

      if !period.end_transition.nil?
        start_offset = format_offset.call(period.offset.std_offset) if !period.start_transition.nil?
        start_time = period.start_transition.local_start_time
        end_offset = format_offset.call(period.end_transition.offset.std_offset)
        end_time = period.end_transition.local_end_time
        reply += " #{start_offset} to #{end_offset}, #{z.strftime('%F', start_time)} to #{z.strftime('%F', end_time)}"
      end

      m.reply reply
    elsif matches.length > 1
      m.reply matches.map(&:identifier).join(', ')[0, 1000]
    else
      m.reply "No zones found for #{query}"
    end
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
    time
  end

  # The logic is messy as we support multiple TZ declaration formats
  # while needing to hack around Chronic parsing quirks.
  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def remind(m)
    bad_timezone_string = 'Specify a timezone at the end: tzid search (US/Pacific), ' \
      '2-letter country code (JP), or offset (+8).'

    victim = m.args[0] == 'me' ? m.sender : m.args[0]
    tokens = m.args.join(' ').match(/(\S+)\s(.+)(on .+|at .+|in .+)$/)

    if !tokens.nil? && tokens.length < 3
      m.reply 'Syntax error: could not parse reminder'
      m.reply @s[:remind][2]
      return
    end

    subject = tokens[2].strip
    time_s = tokens[3].strip

    # Assume relative time
    time_s = time_s.gsub(/\W(s|sec|secs)$/, ' seconds')
    time_s = time_s.gsub(/\W(m|min|mins)$/, ' minutes')
    time_s = time_s.gsub(/\W(h|hr|hour|hours)$/, ' hours')
    time_s = time_s.gsub(/\W(d|day|days)$/, ' days')

    tz = get_timezone_from_identifier(m.args.last)

    # An exact match from a country code with only one timezone
    tz = get_timezone_from_country_code(m, m.args.last.upcase) if tz.nil?
    # Abort if the country has multiple timezones
    return if tz == :ambiguous

    # special case for relative time, eg. remind me in
    tz = get_timezone_from_identifier('UTC') if time_s.split(' ')[0] == 'in' && tz.nil?

    if tz.nil?
      m.reply bad_timezone_string
      return
    end

    time = parse_time(time_s, tz)

    if !time
      m.reply "Could not parse time \"#{time_s}\""
      return
    end

    remind_at = tz.local_to_utc(time)
    seconds_to_trigger = remind_at - Time.now

    if seconds_to_trigger < 0
      m.reply 'I cannot travel back in time!'
      return
    end

    hours_ago = (seconds_to_trigger / 60.0 / 60.0)
    human_time = if hours_ago >= 1
                   "#{hours_ago.round(1)}h"
                 elsif hours_ago <= (1 / 60)
                   "#{(hours_ago * 60).round(0)}m"
                 else
                   "#{(hours_ago * 60 * 60).round(0)}s"
                 end

    EventMachine.add_timer(seconds_to_trigger) do
      m.reply("🔔 -#{human_time} #{m.sender} > #{victim}: #{subject}")
    end

    m.reply "Reminder in #{human_time} set for #{remind_at} (#{tz.identifier})."
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

  def get_timezone_from_identifier(id)
    tz = find_zone(id)
    tz.length == 1 ? tz[0] : nil
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
