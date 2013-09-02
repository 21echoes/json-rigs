module Clinkle
  module FixtureTemplates
    def basic_post_fixture
      fixture :success do
        respond_with %q(
{
    "success": true
}
        )
      end

      fixture :failure do
        respond_with %q(
{
    "error_code": 0, 
    "success": false
}
        )
      end
    end
  end
end
