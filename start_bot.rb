require './bot/core'
ROOT_DIR = Dir.pwd

Bot::Core.new(File.join(ROOT_DIR, "settings", "bot_settings.json"))