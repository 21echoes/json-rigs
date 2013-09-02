require 'net/http'
require 'spec/fixture_server/constants'

module Clinkle
  module FixtureClient
    class << self
      FIXTURE_URI = '/fixtures'

      def clear_active_fixtures
        data = {
          :fixture_action => 'clear'
        }
        post_fixture(data)
      end

      def set_fixture url, method, action, fixture
        data = {
          :url => url,
          :method => method,
          :action => action,
          :fixture => fixture,
          :fixture_action => 'set'
        }
        response = post_fixture(data)

        if response.body.length > 0
          puts "Fixture server error: #{response.body}"
        end
      end

      def fixtures
        data = {
          :fixture_action => 'get'
        }
        response = get_fixture(data)

        if response.body.length > 0
          puts "Fixture server error: #{response.body}"
        end

        puts response.body

        JSON.parse(response.body)
      end

      private

      def get_conn
        begin
          Net::HTTP.new('localhost', File.read(Clinkle::PORT_FILE).to_i)
        rescue Errno::ENOENT
          fail "Failed to find fixture server port file #{Clinkle::PORT_FILE}. Maybe your fixture server is down."
        end
      end

      def get_fixture(data)
        path = FIXTURE_URI.dup
        path << '?' << data.map { |k, v| "#{k}=#{CGI::escape(v.to_s)}" }.join('&')
        request = Net::HTTP::Get.new(path)

        get_conn.request(request)
      end

      def post_fixture(data)
        request = Net::HTTP::Post.new(FIXTURE_URI)
        request.set_form_data(data)

        get_conn.request(request)
      end
    end
  end
end
