module JsonRigs
  class Fixture

    attr_accessor :pause_time
    attr_reader :response

    def respond_with response
      JSON.parse(response)
      @response = response
    end

    alias_method :delay, :pause_time=
  end

  class FixturedAction
    attr_reader :fixtures, :url 
    attr_accessor :active_fixture_name

    def initialize(url, method)
      @active_fixture_name = nil
      @url = url
      @method = method
      @fixtures = {}
    end

    def fixture fixture_name, &block
      fixture = Fixture.new
      @fixtures[fixture_name.to_s] = fixture
      fixture.instance_eval &block
      @active_fixture_name = ''
    end

    def active_fixture; @fixtures[@active_fixture_name] end
    def active_fixture?; !@active_fixture_name.empty? end

    def to_hash
      fixture_hash = @fixtures.keys.each_with_object({}) do |fixture_name, hash|
        hash[fixture_name] = @active_fixture_name == fixture_name
      end

      {
        method: @method,
        fixtures: fixture_hash
      }
    end
  end
end
