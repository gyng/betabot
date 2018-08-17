# This file is for using betabot as a gem.

class Betabot
  Dir[File.expand_path './**/*.rb'].each { |f| require_relative(f) }
end
