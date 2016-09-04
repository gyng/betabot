RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  ENV['TEST'] = 'true'

  # Loads .rb patches intended to be run only once.
  patch_dir = File.join(Dir.pwd, 'lib', 'patches')
  Dir.foreach(patch_dir) do |filename|
    if File.extname(filename) == '.rb'
      puts 'Loading patch file: #{filename}'
      load File.join(patch_dir, filename)
    end
  end

  require 'eventmachine'
  require 'bot/core'

  # Helper method for easier setup/teardown of eventmachine context
  # We setup the bot for each spec as the bot expects to be run in EM as
  # running every spec within a single EM sounds like a terrible idea.
  def with_em
    EM.run do
      yield
      EM.stop
    end
  end

  config.order = 'random'
end
