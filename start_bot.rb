require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

require './lib/bot/core'

Bot::Core.new(File.join(Dir.pwd, "lib", "settings", "bot_settings.json"))