# Share the test process's DB connection with the Capybara server thread to avoid
# deadlocks (two connections writing to the same tables in different order).
# Only active for type: :system examples.

class ActiveRecord::Base
  mattr_accessor :shared_connection
  @@shared_connection = nil

  class << self
    def connection
      @@shared_connection || retrieve_connection
    end
  end
end

RSpec.configure do |config|
  config.before(:each, type: :system) do
    ActiveRecord::Base.shared_connection = ActiveRecord::Base.retrieve_connection
  end

  config.after(:each, type: :system) do
    ActiveRecord::Base.shared_connection = nil
  end
end
