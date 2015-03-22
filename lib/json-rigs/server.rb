require 'listen'
require 'sinatra/base'
require 'socket'
require 'haml'
require 'pathname'

require 'json-rigs/fixture'
require 'json-rigs/fixtures'

module JsonRigs
  class FixtureServer < Sinatra::Base
    configure :production, :development do
      enable :logging
    end

    def self.load_fixtures
      puts "Loading fixtures from #{settings.fixture_path}..."
      Dir[File.join(settings.fixture_path, '**/*.json')].each do |f|
        load_static_fixture(f)
      end
      Dir[File.join(settings.fixture_path, '**/*.rb')].each do |f|
        load_dynamic_fixture(f)
      end
    end

    def self.load_fixture(f)
      File.extname(f) == '.rb' ? load_dynamic_fixture(f) : load_static_fixture(f)
    end

    def self.extract_pieces_or_halt(f)
      relevant_path = f.sub(/\A#{settings.fixture_path}/, '')
      pieces = Pathname(relevant_path).each_filename.to_a

      unless pieces.length >= 2
        error_message = %Q(
          Fixtures are not structured correctly.
          Please place .json files inside #{settings.fixture_path} as /[url]/[HTTP method]/[response type].json, e.g. /users/GET/success.json
        )
        logger.error error_message
        halt error_message
      end

      url = pieces[0...-2].join('/')
      method = pieces[-2]
      response_name = File.basename(pieces[-1], ".*")

      [url, method, response_name]
    end

    def self.load_static_fixture(f)
      puts "Loading #{f}..."
      url, method, response_name = extract_pieces_or_halt(f)
      contents = File.read(f)
      JsonRigs::Fixtures::fixture_action url, method do
        fixture response_name.to_sym do
          respond_with(contents)
        end
      end
    end

    def self.load_dynamic_fixture(f)
      puts "Loading #{f}..."
      url, method, response_name = extract_pieces_or_halt(f)
      contents = File.read(f)
      JsonRigs::Fixtures::fixture_action url, method do
        dynamic_fixture response_name.to_sym, eval(contents)
      end
    end

    def self.remove_fixture(f)
      puts "Removing #{f}..."
      url, method, response_name = extract_pieces_or_halt(f)

      JsonRigs::Fixtures::remove_action url, method, response_name
    end

    helpers do
      def serve_request(servlet_url, params, method)
        action = JsonRigs::Fixtures::find_action(servlet_url, method)
        halt "unknown action '#{servlet_url} #{method}'" unless action

        logger.info "Responding to #{servlet_url} #{method}"

        if action.active_fixture?
          logger.info "Using fixture #{action.active_fixture_name.inspect}"

          fixture = action.active_fixture
          halt 'action has no associated fixture' unless fixture

          if fixture.pause_time
            logger.info "Sleeping #{fixture.pause_time} seconds.."
            sleep(fixture.pause_time)
          end

          if fixture.class == JsonRigs::DynamicFixture
            response = fixture.respond_to params
          else
            response = fixture.response
          end

          content_type 'application/json'
          response
        else
          logger.info 'No fixture specified, using stub response.'
          return 500, "{ \"success\": false, \"error\": \"No fixture specified. Please visit the test panel and chose a fixture for #{method} /#{servlet_url}\" }"
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
        %w{url method fixture}.each do |arg|
          value = params[arg]
          unless value
            logger.error "missing #{arg} param"
            halt "missing #{arg} param"
          end
        end

        action = JsonRigs::Fixtures::find_action(params[:url], params[:method])

        action_str = "#{params[:url]} #{params[:method]}"
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

    get '/test-panel' do
      @fixtures = JsonRigs::Fixtures::fixtures
      haml :test_panel, locals: {fixtures: @fixtures}
    end

    get '/test-fixtures' do
      fixture_action = params[:fixture_action]
      case fixture_action
      when 'get', nil
        get_fixtures
      else
        halt "unknown fixture action #{fixture_action.inspect}"
      end
    end

    post '/test-fixtures' do
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
      serve_request(servlet_url, request.params, :GET)
    end

    post '/*' do |servlet_url|
      serve_request(servlet_url, request.params, :POST)
    end

    put '/*' do |servlet_url|
      serve_request(servlet_url, request.params, :PUT)
    end

    delete '/*' do |servlet_url|
      serve_request(servlet_url, request.params, :DELETE)
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
        listener = Listen.to(fixture_path, only: /\.(json|rb)$/) { |modified, added, removed|
          on_fixture_change(modified, added, removed)
        }
        listener.start

        FixtureServer.run!
      end

      private

      def on_fixture_change(modified, added, removed)
        puts 'Reloading fixtures...'

        removed.map do |f|
          FixtureServer::remove_fixture(f)
        end
        (modified + added).map do |f|
          FixtureServer::load_fixture(f)
        end
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
