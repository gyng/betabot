class Bot::Core::Authenticator
  attr_reader :authenticated_hostnames

  def initialize(path = Bot::SETTINGS_DIR)
    @authentications = nil
    @authenticated_hostnames = {}
    @authentications_path = File.join(path, 'authentication.json')
    load_authentications
  end

  def login(m)
    return false if m.args.length < 2
    user = m.args[0]
    user_info = @authentications[user.to_sym]
    salt = user_info[:salt]
    hash = user_info[:hash]
    password = m.args[1]

    if make_hash(salt, password) == hash
      m.reply(
        "Hello, #{user} (L#{user_info[:auth_level]})! You were last seen on #{user_info[:last_used]} from " \
        "#{user_info[:last_hostname]}, logging in from #{user_info[:last_username]}."
      )

      user_info[:last_used] = Time.now.utc
      user_info[:last_username] = m.sender
      user_info[:last_hostname] = m.hostname
      save_authentications

      @authenticated_hostnames[m.hostname] = user_info[:auth_level]
      Bot.log.info "#{user} has logged in."
    else
      Bot.log.warn "Bad login attempt for #{user}"
    end
  end

  def logout(m)
    return if !@authenticated_hostnames.delete(m.hostname)
    m.reply 'You have been logged out.'
    Bot.log.info 'A user has logged out.'
  end

  def auth(level, m)
    return true if level <= 0
    authed_user = @authenticated_hostnames[m.hostname]
    !authed_user.nil? && authed_user.to_i >= level
  end

  def load_authentications
    begin
      if File.file?(@authentications_path)
        JSON.parse(File.read(@authentications_path))
      else
        File.write(@authentications_path, {}.to_json)
      end
    rescue
      File.write(@authentications_path, {}.to_json)
    end

    @authentications = JSON.parse(File.read(@authentications_path), symbolize_names: true)
  end

  def save_authentications
    File.write(@authentications_path, JSON.pretty_generate(@authentications))
  end

  def make_account(account_name, password, auth_level)
    require 'securerandom'
    require 'base64'

    salt_length = 32
    salt = SecureRandom.hex(salt_length)

    @authentications[account_name] = {
      salt: salt,
      hash: make_hash(salt, password),
      auth_level: auth_level.to_i,
      generated: Time.now.utc,
      last_used: nil,
      last_username: nil,
      last_hostname: nil
    }

    save_authentications
  end

  def make_hash(salt, password)
    Digest::SHA256.hexdigest(salt.to_s + password.to_s)
  end
end
