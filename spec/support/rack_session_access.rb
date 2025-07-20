# Configure rack_session_access for feature tests
RSpec.configure do |config|
  config.before(:each, type: :feature) do
    Capybara.current_driver = :rack_test
  end
end 