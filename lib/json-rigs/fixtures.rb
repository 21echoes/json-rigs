require 'json'

require 'json-rigs/fixture'

module JsonRigs
  module Fixtures
    FixturedActionKey = Struct.new(:url, :method)
    ACTIVE_FIXTURE_FILE = 'tmp/active_fixtures.json'

    def self.fixture_action(url, method, &block)
      method = method.to_s
      @actions ||= {}

      key = _key(url, method)
      fixture_action = @actions[key] || FixturedAction.new(url, method)
      @actions[key] = fixture_action
      fixture_action.instance_eval &block
    end

    def self.find_action(url, method)
      method = method.to_s
      @actions ||= {}
      @actions[_key(url, method)]
    end

    def self.clear_active_fixtures
      @actions.values.each do |action|
        action.active_fixture_name = ''
      end
    end

    def self.save_active_fixtures
      active_fixtures = @actions.map { |key, action|
        [ key.url, key.method, action.active_fixture_name ]
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
        url, method, active_fixture = fixture
        action = find_action(url, method)
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

    def self._key(url, method)
      FixturedActionKey.new(url, method)
    end
  end
end
