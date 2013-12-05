require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

require './lib/bot/core'

Bot::ROOT_DIR = File.join(Dir.pwd, "lib")

Bot::Core.new(File.join(Bot::ROOT_DIR, "settings", "bot_settings.json"))