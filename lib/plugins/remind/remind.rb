require 'date'
require 'tzinfo'
require 'active_support/time'
require 'securerandom'
require 'chronic'

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
        cancel: [
          :cancel, 0,
          'cancel <list|all|id>'
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

    @timers = {}

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
      z.identifier.downcase == query.downcase
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
                 elsif hours.negative? then '-'
                 elsif hours.positive? then '+'
                 end
        "#{prefix}#{hours}h"
      end

      if !period.end_transition.nil?
        start_offset = format_offset.call(period.offset.std_offset) if !period.start_transition.nil?
        start_time = period.start_transition.local_start_at
        end_offset = format_offset.call(period.end_transition.offset.std_offset)
        end_time = period.end_transition.local_end_at
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

    time = with_time_zone('UTC') do
      Chronic.parse(time_s, now: Time.now.utc)
    end

    if time.nil?
      m.reply "Could not parse \"#{time_s}\""
      return
    end

    seconds_to_trigger = time - Time.now

    if seconds_to_trigger.negative?
      m.reply "I cannot travel back in time! (#{time})"
      return
    end

    handle = EventMachine::Timer.new(seconds_to_trigger) do
      min_ago = (seconds_to_trigger / 60.0).round(1)
      m.reply("🕛 -#{min_ago}m #{m.sender}")
    end

    time_s = human_time(seconds_to_trigger)

    hash = add_timer_entry(handle, m.sender, time_s, get_fut_timestamp_sec(seconds_to_trigger))

    cancel_s = "(cancel id #{hash} to cancel)".gray
    m.reply "Timer in #{time_s.bold.red} set for #{time}. #{cancel_s}"
    time
  end

  # The logic is messy as we support multiple TZ declaration formats
  # while needing to hack around Chronic parsing quirks.
  # rubocop:disable Metrics/MethodLength
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

    tz = get_timezone_from_identifier(m.args.last)

    # An exact match from a country code with only one timezone
    tz = get_timezone_from_country_code(m, m.args.last.upcase) if tz.nil?
    # Abort if the country has multiple timezones
    return if tz == :ambiguous

    time_s = time_s.gsub(m.args.last, '').strip if tz

    # special case for relative time, eg. remind me in
    if time_s.split(' ')[0] == 'in'
      tz = get_timezone_from_identifier('UTC') if tz.nil?

      time_s = time_s.gsub(/(s|sec|secs)$/, ' seconds')
      time_s = time_s.gsub(/(m|min|mins)$/, ' minutes')
      time_s = time_s.gsub(/(h|hr|hour|hours)$/, ' hours')
      time_s = time_s.gsub(/(d|day|days)$/, ' days')
    end

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

    treat_as_next_day = false
    if seconds_to_trigger.negative?
      seconds_in_day = 60 * 60 * 24
      if seconds_to_trigger.abs < seconds_in_day
        treat_as_next_day = true
        seconds_to_trigger += seconds_in_day
      else
        m.reply "I cannot travel back in time! (#{time_s}, #{tz})"
        return
      end
    end

    time_s = human_time(seconds_to_trigger)

    handle = EventMachine::Timer.new(seconds_to_trigger) do
      # Reconnect persistence hack
      # @origin changes when reconnecting, so we mutate! the original message
      current_handler = @bot.adapters[m.adapter].handler
      m.origin = current_handler if current_handler != m.origin
      m.reply("🔔 -#{time_s} #{m.sender} > #{victim}: #{subject}")
    rescue StandardError
      m.reply("🔔 -#{time_s} #{m.sender} > #{victim}: #{subject}")
    end

    hash = add_timer_entry(handle, m.sender, subject, get_fut_timestamp_sec(seconds_to_trigger))

    cancel_s = "(cancel id #{hash} to cancel)".gray
    m.reply "Reminder in #{time_s.bold.red} set for " \
      "#{treat_as_next_day ? 'tomorrow '.red.bold : ''}#{remind_at} (#{tz.identifier}). #{cancel_s}"
  end
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity

  def cancel(m)
    case m.mode
    when 'all'
      rm = clear_timers_by_user_id(m.sender)
      m.reply "Timers removed: #{rm.length}."
    when 'list'
      timers = get_timers_by_user_id(m.sender)
      if timers.empty?
        m.reply timers
          .map { |_, v| "(#{v[:hash]}, #{v[:subject]}, #{v[:timestamp]})" }
          .join(', ')
      else
        m.reply 'You have no pending timers.'
      end
    when 'id'
      rm = remove_timer_entry(m.sender, m.args[1])
      if rm
        m.reply "Removed (#{rm[:hash]}, #{rm[:subject]}, #{rm[:timestamp]})."
      else
        m.reply "No entry found for #{m.args[1]}."
      end
    else
      m.reply "Unknown mode #{m.mode}. <all|list|id hash>."
    end
  end

  private

  def human_time(seconds_to_trigger)
    mins_ago = seconds_to_trigger / 60.0
    hours_ago = mins_ago / 60.0
    if hours_ago >= 1
      "#{hours_ago.round(1)}h"
    elsif mins_ago < 1
      "#{seconds_to_trigger.round(0)}s"
    else
      "#{mins_ago.round(0)}m"
    end
  end

  def get_fut_timestamp_sec(sec)
    timestamp = Time.now.to_i + sec
    Time.at(timestamp)
  end

  def add_timer_entry(timer_handle, user_id, subject, timestamp)
    hash = SecureRandom.hex(2)
    # Collision
    hash = SecureRandom.hex(3) if @timers[hash]

    @timers[hash] = {
      hash:,
      user_id:,
      timer_handle:,
      subject:,
      timestamp:
    }
    hash
  end

  def remove_timer_entry(user_id, hash)
    to_remove = @timers[hash]
    if to_remove && to_remove[:user_id] == user_id
      to_remove[:timer_handle].cancel
      @timers.delete to_remove[:hash]
      return to_remove
    end
    nil
  end

  def clear_timers_by_user_id(user_id)
    to_clear = get_timers_by_user_id(user_id)
    to_clear.each { |_, v| EventMachine.cancel_timer(v[:timer_handle]) }
    @timers.delete_if { |_, v| v[:user_id] == user_id }
    to_clear
  end

  def get_timers_by_user_id(user_id)
    @timers.filter { |_, v| v[:user_id] == user_id }
  end

  def with_time_zone(tz_name)
    prev_tz = ENV['TZ']
    ENV['TZ'] = tz_name
    yield
  ensure
    ENV['TZ'] = prev_tz
  end

  def parse_time(time_s, tz)
    # Required Chronic hack.
    now = case tz
          when TZInfo::Timezone
            tz.utc_to_local(Time.now.utc)
          when Numeric
            Time.now.utc.change(offset: tz)
          else
            Time.now.utc
          end
    time_s = time_s.gsub(/^at /, '') # Chronic cannot parse "at 10pm tomorrow"

    with_time_zone('UTC') do
      parsed = Chronic.parse(time_s, now:)

      # Try to parse without last argument as it could be a tz
      if parsed.nil?
        time_s = time_s.split(' ')[0...-1].join(' ')
        parsed = Chronic.parse(time_s, now:)
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
# rubocop:enable Metrics/ClassLength
