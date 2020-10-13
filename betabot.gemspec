Gem::Specification.new do |s|
  s.name        = 'betabot'
  s.version     = '0.0.1'
  s.licenses    = ['MIT']
  s.summary     = 'Betabot as a lib.'
  s.description = 'Betabot as a lib. Mostly for testing external plugins.'
  s.authors     = ['gyng']
  s.files       = Dir['lib/**/*.rb'] + Dir['lib/betabot.rb']
  s.homepage    = 'https://github.com/gyng/betabot/'
  s.metadata    = {}
  s.required_ruby_version = '2.7'

  s.add_runtime_dependency 'git'
  s.add_runtime_dependency 'sequel'
  s.add_runtime_dependency 'sqlite3'
end
