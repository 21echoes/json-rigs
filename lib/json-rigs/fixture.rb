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

  class DynamicFixture < Fixture
    attr_accessor :dynamic_response

    def respond_to params
      @dynamic_response.call(params)
    end
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
    end

    def dynamic_fixture fixture_name, proc
      fixture = DynamicFixture.new
      @fixtures[fixture_name.to_s] = fixture
      fixture.dynamic_response = proc
    end

    def active_fixture; @fixtures[@active_fixture_name] end
    def active_fixture?; !@active_fixture_name.empty? end

    def active_fixture_name=(fixture_name)
      return unless has_fixture?(fixture_name) or fixture_name.empty?
      @active_fixture_name = fixture_name
    end

    def has_fixture? fixture_name
      @fixtures[fixture_name.to_s]
    end

    def remove_fixture fixture_name
      if @active_fixture_name == fixture_name
        @active_fixture_name = ''
      end
      @fixtures.delete(fixture_name)
    end

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
