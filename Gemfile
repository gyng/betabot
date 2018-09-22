require 'json'

source 'https://rubygems.org'

gem 'activesupport'
gem 'eventmachine'
gem 'git'
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
end

# Adapter Gemfiles
# rubocop:disable Security/Eval
adapters_path = File.join(File.dirname(__FILE__), 'lib', 'adapters', '**', 'Gemfile')
Dir.glob(adapters_path) do |gemfile|
  # Dangerous! However, if we want to load additional `Gemfile`s we need to `eval`...
  eval(IO.read(gemfile), binding)
end

# Plugin Gemfiles
plugins_path = File.join(File.dirname(__FILE__), 'lib', 'plugins', '**', 'Gemfile')
external_plugins_path = File.join(File.dirname(__FILE__), 'lib', 'external_plugins', '**')

Dir.glob(plugins_path) do |gemfile|
  # Dangerous!
  eval(IO.read(gemfile), binding)
end

Dir.glob(external_plugins_path) do |dir|
  path = File.join(dir, 'manifest.json')
  next if !File.file? path

  manifest = JSON.parse(File.read(path), symbolize_names: true)
  has_dependencies = manifest[:has_dependencies]
  # Dangerous!
  eval(IO.read(gemfile), binding) if has_dependencies
end
# rubocop:enable Security/Eval
