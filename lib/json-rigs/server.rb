require 'listen'
require 'sinatra/base'
require 'socket'

require 'json-rigs/fixture'
require 'json-rigs/fixtures'

module JsonRigs
  class FixtureServer < Sinatra::Base
    configure :production, :development do
      enable :logging
    end

    def self.load_fixtures
      puts "Loading fixtures from #{settings.fixture_path}..."
      Dir[File.join(settings.fixture_path, '**/*.rb')].each do |f|
        puts "Loading #{f}..."
        load(f)
      end
    end

    helpers do
      def serve_request(servlet_url, method)
        action_name = params[:action]
        halt 'missing action param' unless action_name

        action = JsonRigs::Fixtures::find_action(servlet_url, method, action_name)
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
        JsonRigs::Fixtures::clear_active_fixtures
        logger.info 'Fixture clear successful.'
        return 200
      end

      def get_fixtures
        JsonRigs::Fixtures::fixtures.to_json
      end

      def set_active_fixture
        %w{url method action fixture}.each do |arg|
          value = params[arg]
          unless value
            logger.error "missing #{arg} param"
            halt "missing #{arg} param"
          end
        end

        action = JsonRigs::Fixtures::find_action(params[:url], params[:method], params[:action])

        action_str = "#{params[:url]} #{params[:method]} #{params[:action]}"
        unless action
          logger.error "unknown action #{action_str}"
          halt "unknown action #{action_str}"
        end
        action.active_fixture_name = params[:fixture]

        JsonRigs::Fixtures::save_active_fixtures

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

      def start(fixture_path)
        puts 'Starting fixture server...'

        port = choose_port()

        FixtureServer.set(:port, port)
        FixtureServer.set(:fixture_path, fixture_path)
        FixtureServer::load_fixtures
        JsonRigs::Fixtures::load_active_fixtures

        # Start listener on fixture path to reload fixtures if necessary.
        Listen.to(fixture_path)
          .filter(/\.rb$/)
          .change(&method(:on_fixture_change))
          .start

        FixtureServer.run!
      end

      private

      def on_fixture_change(modified, added, removed)
        puts 'Reloading fixtures...'

        JsonRigs::Fixtures::clear_all!
        FixtureServer::load_fixtures
        JsonRigs::Fixtures::load_active_fixtures

        puts 'Fixtures reloaded.'
      end

      def choose_port
        port = STARTING_PORT

        begin
          server = TCPServer.new(port)
        rescue Errno::EADDRINUSE
          port += 1
          retry
        ensure
          server.close if server
        end

        port
      end
    end
  end
end
