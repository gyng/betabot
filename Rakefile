task :add_account do
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
    authenticator.make_account(account_name, auth_level, password)
    puts "Account #{account_name} created."
  end
end

# Run with `rake make_plugin[name]`
task :make_plugin, :name do |t, args|
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
end