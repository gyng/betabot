require 'rubygems'
require 'bundler/setup'
# Bundler.require(:default)

require 'eventmachine'
require './lib/bot/core'

EM.run { Bot::Core.new(File.join(Dir.pwd, "lib", "settings", "bot_settings.json")) }