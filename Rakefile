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