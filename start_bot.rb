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
puts 'Loading settings from #{settings_path}...'

EM.run { Bot::Core.new(settings_path) }
if $restart
  exec "ruby #{__FILE__}"
else
  Kernel.abort
end
