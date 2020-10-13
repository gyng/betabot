# This file is for using betabot as a gem.
require_relative('patches/ansi_string')
require_relative('bot/core')
Dir[File.expand_path './lib/*.rb'].each do |f|
  require_relative(f)
end
