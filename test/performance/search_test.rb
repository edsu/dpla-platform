require 'test_helper'
require 'rails/performance_test_help'

class SearchTest < ActionDispatch::PerformanceTest
  # Refer to the documentation for all available options
  # self.profile_options = { :runs => 5 }
  #                          :output => 'tmp/performance', :formats => [:flat] }

  def setup
    @api_key = 'aa22c5ec71f95032dbcba4afc2041deb'
  end


  test "test_search_empty" do
    get "/v2/items?api_key=#{ @api_key }"
  end
end
