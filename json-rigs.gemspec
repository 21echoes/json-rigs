$:.push File.expand_path('../lib', __FILE__)

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'json-rigs'
  s.version     = '3.0.0'
  s.date        = '2015-03-21'
  s.authors     = ['Clinkle','David Kettler']
  s.email       = ['alex@clinkle.com','21echoes@gmail.com']
  s.homepage    = 'https://github.com/21echoes/json-rigs'
  s.summary     = '~~ set sail with json-rigs ~~'
  s.executables = [ 'jrigs' ]
  s.files       = %w(
    lib/json-rigs.rb
    lib/json-rigs/client.rb
    lib/json-rigs/fixture.rb
    lib/json-rigs/fixtures.rb
    lib/json-rigs/server.rb
  )
  s.license     = 'MIT'

  s.description = 'Serve fixtured API responses quickly and easily. ' +
    'Runs a tiny sinatra server that serves static .json files or dynamic .rb files from disk. ' +
    'Control which fixtures are being used at localhost:port/test-panel. ' +
    'Great for QA and fast prototyping.'

  s.add_dependency 'daemons', '~> 1.2'
  s.add_dependency 'json', '~> 1.8'
  s.add_dependency 'listen', '~> 2.9'
  s.add_dependency 'sinatra', '~> 1.4'
  s.add_dependency 'haml', '~> 4.0'
end
