source 'https://rubygems.org'

gem 'activesupport'
gem 'eventmachine'
gem 'mechanize'
gem 'nokogiri'
gem 'open_uri_redirections'
gem 'rest-client'
gem 'sequel'
gem 'sinatra'
gem 'sqlite3'
gem 'thin'

group :development, :test do
  gem 'rake'
  gem 'rspec'
  gem 'rubocop'
  gem 'rubyzip'
end

# Adapter Gemfiles
adapters_path = File.join(File.dirname(__FILE__), 'lib', 'adapters', '**', 'Gemfile')
Dir.glob(adapters_path) do |gemfile|
  # Dangerous! However, if we want to load additional `Gemfile`s we need to `eval`...
  # rubocop:disable Security/Eval
  eval(IO.read(gemfile), binding)
end

# Plugin Gemfiles
plugins_path = File.join(File.dirname(__FILE__), 'lib', 'plugins', '**', 'Gemfile')
Dir.glob(plugins_path) do |gemfile|
  # Dangerous!
  eval(IO.read(gemfile), binding)
end
