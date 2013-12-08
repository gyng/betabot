require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

require './lib/bot/core'

$restart = false

# Loads .rb patches intended to be run only once.
patch_dir = File.join(Dir.pwd, 'lib', 'patches')
Dir.foreach(patch_dir) do |filename|
  if File.extname(filename) == '.rb'
    puts "Loading patch file: #{filename}"
    load File.join(patch_dir, filename)
  end
end

# Thread.abort_on_exception = true
EM.run { Bot::Core.new(File.join(Dir.pwd, 'lib', 'settings', 'bot_settings.json')) }
exec "ruby #{__FILE__}" if $restart