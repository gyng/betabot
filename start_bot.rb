require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

require './lib/bot/core'

$shutdown = false
$restart = false

# Loads .rb patches intended to be run only once.
patch_dir = File.join(Dir.pwd, 'lib', 'patches')
Dir.foreach(patch_dir) do |filename|
  if File.extname(filename) == '.rb'
    puts "Loading patch file: #{filename}"
    load File.join(patch_dir, filename)
  end
end

override = File.join(Dir.pwd, 'lib', 'settings', 'bot_settings.user.json')
default = File.join(Dir.pwd, 'lib', 'settings', 'bot_settings.json')
settings_path = File.exist?(override) ? override : default

if ARGV[0] == '--dev'
  puts 'Running in dev mode...'
  Thread.abort_on_exception = true
end

if ARGV[0] == '--ssl-no-verify'
  puts 'Accepting invalid SSL certificates...'
  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
end

EM.run { Bot::Core.new(settings_path) }
if $restart
  exec "ruby #{__FILE__}"
else
  Kernel.abort
end
