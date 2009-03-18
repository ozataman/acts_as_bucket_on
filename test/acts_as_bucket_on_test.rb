require 'test_helper'

class ActsAsBucketOnTest < ActiveSupport::TestCase
  test "that conditions are handled as expected" do
    assert_raise InvalidConditions { BucketableModel.send(:build_bucketing_condition, :trial, {:conditions => 1234}) }
    assert_nothing_raised { BucketableModel.send(:build_bucketing_condition, :trial, {:conditions => :name}) }
  end
end
