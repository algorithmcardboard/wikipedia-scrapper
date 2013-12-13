require 'test_helper'

class EventControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
  end

  test "should get date" do
    get :date
    assert_response :success
  end

end
