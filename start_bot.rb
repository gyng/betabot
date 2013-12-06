require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

require './lib/bot/core'

$restart = false

EM.run { Bot::Core.new(File.join(Dir.pwd, "lib", "settings", "bot_settings.json")) }
exec "ruby #{__FILE__}" if $restart