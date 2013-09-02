require 'listen'
require 'socket'
require 'spec/fixture_server/constants'
require 'spec/fixture_server/fixture'
require 'sinatra/base'

module Clinkle
  class FixtureServer < Sinatra::Base
    configure :production, :development do
      enable :logging
    end

    def self.load_fixtures
      Dir[File.join(settings.fixture_path, '**/*.rb')].each do |f| load (f) end
    end

    helpers do
      def serve_request(servlet_url, method)
        action_name = params[:action]
        halt 'missing action param' unless action_name

        action = Clinkle::Fixtures::find_action(servlet_url, method, action_name)
        halt "unknown action '#{servlet_url} #{method} #{action_name}'" unless action

        logger.info "Responding to #{servlet_url} #{method} #{action_name}"

        if action.active_fixture?
          logger.info "Using fixture #{action.active_fixture_name.inspect}"

          fixture = action.active_fixture
          halt 'action has no associated fixture' unless fixture

          if fixture.pause_time
            logger.info "Sleeping #{fixture.pause_time} seconds.."
            sleep(fixture.pause_time)
          end

          content_type 'application/json'
          return fixture.response
        else
          logger.info 'No fixture specified, using stub response.'
          return '{ "success": false, "error_code": 0 }'
        end
      end

      def clear_fixtures
        Clinkle::Fixtures::clear_active_fixtures
        logger.info 'Fixture clear successful.'
        return 200
      end

      def get_fixtures
        Clinkle::Fixtures::fixtures.to_json
      end

      def set_active_fixture
        %w{url method action fixture}.each do |arg|
          value = params[arg]
          unless value
            logger.error "missing #{arg} param"
            halt "missing #{arg} param"
          end
        end

        action = Clinkle::Fixtures::find_action(params[:url], params[:method], params[:action])

        action_str = "#{params[:url]} #{params[:method]} #{params[:action]}"
        unless action
          logger.error "unknown action #{action_str}"
          halt "unknown action #{action_str}"
        end
        action.active_fixture_name = params[:fixture]

        Clinkle::Fixtures::save_active_fixtures

        logger.info "Setting fixture for #{action_str} to #{params[:fixture]}"

        return 200
      end
    end

    get '/fixtures' do
      fixture_action = params[:fixture_action]
      case fixture_action
      when 'get'
        get_fixtures
      else
        halt "unknown fixture action #{fixture_action.inspect}"
      end
    end

    post '/fixtures' do
      fixture_action = params[:fixture_action]
      case fixture_action
      when 'clear'
        clear_fixtures
      when 'set'
        set_active_fixture
      else
        halt "unknown fixture action #{fixture_action.inspect}"
      end
    end

    get '/*' do |servlet_url|
      serve_request(servlet_url, :GET)
    end

    post '/*' do |servlet_url|
      serve_request(servlet_url, :POST)
    end
  end

  module FixtureServerRunner
    class << self
      STARTING_PORT = 3000

      def _choose_port
        port = STARTING_PORT
        begin
          server = TCPServer.new(port)
        rescue Errno::EADDRINUSE
          port += 1
          retry
        end
        server.close
        port
      end

      def start(fixture_path)
        puts 'Starting fixture server...'

        port = _choose_port()

        File.open(PORT_FILE, 'w') do |io| io.write(port) end

        FixtureServer.set(:port, port)
        FixtureServer.set(:fixture_path, fixture_path)
        FixtureServer::load_fixtures
        Clinkle::Fixtures::load_active_fixtures

        # Start listener on fixture path to reload fixtures if necessary.
        listener = Listen.to(fixture_path)
        listener.filter(/\.rb$/)
        listener.change do
          puts 'Reloading fixtures...'
          Clinkle::Fixtures::clear_all!
          FixtureServer::load_fixtures
          Clinkle::Fixtures::load_active_fixtures
          puts 'Fixtures reloaded.'
        end
        listener.start(false)

        FixtureServer.run!
      end
    end
  end

  module Fixtures
    FixturedActionKey = Struct.new(:url, :method, :action)
    ACTIVE_FIXTURE_FILE = 'tmp/active_fixtures.json'

    def self.fixture_action(url, method, action, &block)
      method = method.to_s
      @actions ||= {}

      key = _key(url, method, action)
      fixture_action = @actions[key] || FixturedAction.new(url, method, action)
      @actions[key] = fixture_action
      fixture_action.instance_eval &block
    end

    def self.find_action(url, method, action)
      method = method.to_s
      @actions ||= {}
      @actions[_key(url, method, action)]
    end

    def self.clear_active_fixtures
      @actions.values.each do |action|
        action.active_fixture_name = ''
      end
    end

    def self.save_active_fixtures
      active_fixtures = @actions.map { |key, action|
        [ key.url, key.method, key.action, action.active_fixture_name ]
      }
      FileUtils.mkdir_p(File.dirname(ACTIVE_FIXTURE_FILE))
      File.open(ACTIVE_FIXTURE_FILE, 'w') { |io| io.write(active_fixtures.to_json) }
    end

    def self.load_active_fixtures
      begin
        active_fixtures = JSON.parse(File.read(ACTIVE_FIXTURE_FILE))
      rescue Errno::ENOENT, Errno::ESRCH
        return
      end

      active_fixtures.each do |fixture|
        url, method, action_name, active_fixture = fixture
        action = find_action(url, method, action_name)
        if action
          action.active_fixture_name = active_fixture
        end
      end
    end

    def self.clear_all!
      @actions = {}
    end

    def self.fixtures
      json = @actions.values.group_by(&:url)
      json.each do |url, actions|
        json[url] = actions.map(&:to_hash)
      end
      json
    end

    def self._key(url, method, action)
      FixturedActionKey.new(url, method, action)
    end
  end
end
