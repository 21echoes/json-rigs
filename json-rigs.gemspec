$:.push File.expand_path('../lib', __FILE__)

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'json-rigs'
  s.version     = '1.0.0'
  s.date        = '2013-09-01'
  s.authors     = ['Clinkle']
  s.email       = ['alex@clinkle.com']
  s.homepage    = 'https://github.com/Clinkle/json-rigs'
  s.summary     = '~~ set sail with json-rigs ~~'
  s.files       = %w(
    lib/json-rigs.rb
    lib/json-rigs/client.rb
    lib/json-rigs/constants.rb
    lib/json-rigs/fixture.rb
    lib/json-rigs/server.rb
    lib/json-rigs/templates.rb
  )
  s.license     = 'MIT'

  s.description = 'An easy way to serve fixtures in response to web requests.' + 
    'Use a handy panel to choose which fixtures to serve. Great for QA and fast prototyping.'

  s.add_dependency 'sinatra'
end
