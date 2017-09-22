class Bot::Plugin::Shipment < Bot::Plugin
  def initialize(bot)
    @s = {
      trigger: { shipment: [
        :shipment, 0,
        'shipment (add <name> <courier_slug> <code>|status <name>|delete <name>|list|courier <search_query>) '\
        '🚢 Track shipments and manage them using Aftership. Shipments are namespaced to user(name)s.'
      ] },
      subscribe: true,
      aftership_api_key: 'Get from https://secure.aftership.com/#/settings/api',
      aftership_endpoint: 'https://api.aftership.com/v4',
      tracked_shipments: {}
    }

    super(bot)
  end

  def aftership_headers
    { 'aftership-api-key' => @s[:aftership_api_key], 'Content-Type' => 'application/json' }
  end

  def get_entry(username, name)
    puts @s[:tracked_shipments], username, name

    if @s[:tracked_shipments][username.intern]
      return @s[:tracked_shipments][username.intern][name.intern]
    end

    nil
  end

  def shipment(m)
    if !@s[:aftership_api_key]
      m.reply 'Get an API key from https://secure.aftership.com/#/settings/api'
    end

    case m.mode
    when 'add'
      track(m)
    when 'track'
      track(m)
    when 'status'
      status(m)
    when 'delete'
      untrack(m)
    when 'untrack'
      untrack(m)
    when 'list'
      list(m)
    when 'courier'
      couriers(m)
    else
      m.reply @s[:trigger][:shipment][2]
    end
  end

  def couriers(m)
    query = m.args[1..-1].join(' ').downcase
    url = "#{@s[:aftership_endpoint]}/couriers/all"
    res = JSON.parse(RestClient.get(url, aftership_headers), symbolize_names: true)
    couriers = res[:data][:couriers]

    results = couriers.find_all { |c| c[:name].downcase.include?(query) || c[:other_name].downcase.include?(query) }

    if results.empty?
      m.reply 'No matching courier found. See https://www.aftership.com/couriers for list.'
    else
      m.reply results[0..10].map { |c| c[:slug] }.join(', ')
    end
  end

  def track(m)
    name = m.args[1]
    courier = m.args[2]
    code = m.args[3]

    url = "#{@s[:aftership_endpoint]}/trackings"

    body = {
      tracking: {
        slug: courier,
        tracking_number: code,
        title: name
      }
    }.to_json

    begin
      res = JSON.parse(RestClient.post(url, body, aftership_headers), symbolize_names: true)
    rescue StandardError => e
      m.reply 'Error tracking package. Verify tracking code, or check courier slug ' \
        "using `shipment courier #{courier || '<courier>'}`. " \
        'Usage: `shipment add <name> <courier_slug> <code>`'

      Bot.log.warn "#{self.class.name} - Failed to track package #{e}"
      return
    end

    @s[:tracked_shipments][m.sender.to_sym] ||= {}
    @s[:tracked_shipments][m.sender.to_sym][name.to_sym] = {
      id: res[:data][:tracking][:id],
      slug: res[:data][:tracking][:slug],
      created: Time.now.utc
    }
    save_settings
    m.reply "Added shipment tracking for \"#{name}\". Use `shipment status #{name}` in a bit to get the status."
  end

  def untrack(m)
    name = m.args[1]
    entry = get_entry(m.sender, name)

    if entry
      begin
        url = "#{@s[:aftership_endpoint]}/trackings/#{entry[:id]}"
        RestClient.delete(url, aftership_headers)
      rescue StandardError => e
        Bot.log.warn "#{self.class.name} - Could not delete remotely #{e}"
      end

      @s[:tracked_shipments][m.sender.intern].delete(name.intern)
      save_settings
      m.reply "Deleted #{name}."
      return
    end

    m.reply 'You do not seem to have such a tracking entry.'
  end

  def list(m)
    entries = @s[:tracked_shipments][m.sender.intern] ? @s[:tracked_shipments][m.sender.intern].keys : []

    if entries.empty?
      m.reply 'Empty!'
    else
      m.reply @s[:tracked_shipments][m.sender.intern].map { |k, v|
        "#{k.to_s.bold} (#{v[:slug]} #{v[:id]} #{v[:created]})"
      }.join(', ')
    end
  end

  def status(m)
    name = m.args[1]
    entry = get_entry(m.sender, name)

    if !entry
      m.reply 'No such tracking entry found.'
      return
    end

    url = "#{@s[:aftership_endpoint]}/last_checkpoint/#{entry[:id]}"
    res = JSON.parse(RestClient.get(url, aftership_headers), symbolize_names: true)

    if res[:meta][:code] != 200
      m.reply "#{res[:meta][:code]}: could not get tracking status."
      return
    end

    data = res[:data]
    chk = data[:checkpoint]

    code = "(#{data[:slug]} #{data[:tracking_number]})"
    location = [chk[:zip], chk[:city], chk[:country_name]].reject { |s| s.nil? || s.empty? }.join(' ')
    formatted_response = [chk[:checkpoint_time], location, chk[:message]].reject { |s| s.nil? || s.empty? }
                                                                         .join(' — ')

    m.reply "#{data[:tag].bold}: #{formatted_response} #{code}"

    m.reply "🎉 Done! Delete your 🎁 tracking with `shipment delete #{name}`" if data[:tag] == 'Delivered'
  end
end
