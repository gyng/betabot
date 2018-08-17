task :make_user do
  require 'io/console'
  require 'json'
  require 'securerandom'
  require 'base64'

  require_relative('./lib/bot/core')
  require_relative('./lib/bot/core/authenticator')

  path = File.join('lib', 'settings')
  authenticator = Bot::Core::Authenticator.new(path)

  puts 'Enter account name:'
  account_name = STDIN.gets.chomp
  puts 'Enter authentication level (number 1-5, 5 being highest):'
  auth_level = STDIN.gets.chomp.to_i
  puts 'Enter password:'
  password = STDIN.noecho(&:gets).chomp
  puts 'Enter password again:'
  password_confirmation = STDIN.noecho(&:gets).chomp

  if password != password_confirmation
    puts 'Password does not match confirmation, try again.'
  else
    authenticator.make_account(account_name, password, auth_level)
    puts "Account #{account_name} created."
  end
end

task :make_user_cmd do |_t, args|
  require 'json'
  require 'securerandom'
  require 'base64'

  require_relative('./lib/bot/core')
  require_relative('./lib/bot/core/authenticator')

  path = File.join('lib', 'settings')
  authenticator = Bot::Core::Authenticator.new(path)
  authenticator.make_account(args[:name], args[:password], args[:auth_level])
end

# Run with `rake make_plugin[name]`
task :make_plugin, :name do |_t, args|
  require 'fileutils'

  name = args[:name]

  dir = File.join('lib', 'plugins', name)
  FileUtils.mkdir_p(dir)
  template = File.join('lib', 'plugins', 'ping', 'ping.rb')
  plugin = File.join(dir, name + '.rb')
  FileUtils.cp(template, plugin)

  to_edit = File.read(plugin)
  name_sentence_case = name[0].upcase + name[1..-1]
  to_edit.gsub!('Ping', name_sentence_case)
  to_edit.gsub!('ping', name.downcase)

  File.write(plugin, to_edit)

  FileUtils.mkdir_p(File.join(dir, 'settings'))
  File.write(File.join(dir, 'settings', '.gitignore'), 'settings.json')
end

task :install_plugin, :url do |_t, args|
  load 'lib/patches/ansi_string.rb'
  load 'lib/bot/core/plugin_installer.rb'

  url = args[:url]

  if url.nil?
    puts 'USAGE: rake install_plugin[$MANIFEST_URL]'
  else
    manifest = get_manifest(url)
    plugin_install(manifest)
  end
end

task :update_plugin, :name do |_t, args|
  load 'lib/patches/ansi_string.rb'
  load 'lib/bot/core/plugin_installer.rb'

  name = args[:name]

  if name.nil?
    puts 'USAGE: rake update_plugin[$NAME]'
  else
    plugin_update(name, 'master')
  end
end

task :remove_plugin, :name do |_t, args|
  load 'lib/patches/ansi_string.rb'
  load 'lib/bot/core/plugin_installer.rb'

  name = args[:name]

  if name.nil?
    puts 'USAGE: rake remove_plugin[$NAME]'
  else
    plugin_remove(name)
  end
end
