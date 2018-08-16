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
  require 'git'
  require 'json'
  require 'open-uri'

  url = args[:url]

  puts "ℹ Grabbing manifest from #{url}..."
  manifest = open(url).read

  puts 'ℹ Parsing manifest JSON...'
  parsed = JSON.parse(manifest, symbolize_names: true)
  puts "ℹ Parsed manifest: #{parsed}"

  repo = parsed[:git]
  plugin_name = parsed[:name]
  puts "ℹ Git repo is at #{repo}"

  plugins_dir = 'lib/plugins'
  FileUtils.mkdir_p(plugins_dir)
  plugin_path = File.join(plugins_dir, plugin_name)

  if File.directory?(plugin_path)
    puts "🔥 Directory #{plugin_path} already exists! Delete it first or run `rake update_plugin[#{plugin_name}]`"
    next
  end

  puts 'ℹ Cloning plugin...'
  Git.clone(repo, plugin_name, path: plugins_dir)

  puts "ℹ Plugin #{plugin_name} installed. Run `bundle install` if needed."
end

task :update_plugin, :name do |_t, args|
  require 'git'

  name = args[:name]
  plugin_path = File.join('lib', 'external_plugins', name)

  puts "ℹ Updating plugin #{name} at #{plugin_path}..."

  g = Git.open(plugin_path)
  g.pull

  puts "ℹ Plugin #{name} updated to #{g.show('HEAD')}."
end
