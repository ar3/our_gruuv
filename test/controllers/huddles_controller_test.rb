require "test_helper"

class HuddlesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get huddles_index_url
    assert_response :success
  end

  test "should get show" do
    get huddles_show_url
    assert_response :success
  end

  test "should get new" do
    get huddles_new_url
    assert_response :success
  end

  test "should get create" do
    get huddles_create_url
    assert_response :success
  end
end
