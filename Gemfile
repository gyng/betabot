source 'http://rubygems.org'

gem 'nokogiri'
gem 'mechanize'
gem 'eventmachine'
gem 'sequel'
gem 'sqlite3'
gem 'rake'
gem 'rubyzip', :require => false
gem 'sinatra'
gem 'thin'

# gem 'colorize'
# gem 'linguistics'
# gem "activesupport-inflector", "~> 0.1.0"

group :development do
  gem 'rspec'
end

# Adapter Gemfiles
Dir.glob(File.join(File.dirname(__FILE__), 'lib', 'adapters', '**', "Gemfile")) do |gemfile|
    eval(IO.read(gemfile), binding)
end

# Plugin Gemfiles
Dir.glob(File.join(File.dirname(__FILE__), 'lib', 'plugins', '**', "Gemfile")) do |gemfile|
    eval(IO.read(gemfile), binding)
end
