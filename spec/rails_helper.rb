# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
# Uncomment the line below in case you have `--require rails_helper` in the `.rspec` file
# that will avoid rails generators crashing because migrations haven't been run yet
# return unless Rails.env.test?
require 'rspec/rails'
require 'rack_session_access/capybara'
require 'factory_bot_rails'
require 'pundit/rspec'
require 'database_cleaner/active_record'

# Configure Capybara
require 'capybara/rspec'
require 'selenium-webdriver'

Capybara.register_driver :selenium_chrome do |app|
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: Selenium::WebDriver::Chrome::Options.new(args: %w[headless disable-gpu no-sandbox disable-dev-shm-usage]))
end

Capybara.javascript_driver = :selenium_chrome
Capybara.default_max_wait_time = 5
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

# Ensures that the test database schema matches the current schema file.
# If there are pending migrations it will invoke `db:test:prepare` to
# recreate the test database by loading the schema.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]

  # Database cleaning strategy
  # Use transactional fixtures for non-system tests (fast)
  # Use database_cleaner truncation for system tests (reliable with Selenium)
  config.use_transactional_fixtures = true
  
  # Configure database_cleaner for system tests
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end
  
  config.before(:each) do
    DatabaseCleaner.start
  end
  
  config.after(:each) do
    DatabaseCleaner.clean
  end
  
  # Override database cleaning strategy for system tests
  config.before(:each, type: :system) do
    DatabaseCleaner.strategy = :truncation
  end
  
  config.after(:each, type: :system) do
    DatabaseCleaner.strategy = :transaction
  end

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails uses metadata to mix in different behaviours to your tests,
  # for example enabling you to call `get` and `post` in request specs. e.g.:
  #
  #     RSpec.describe UsersController, type: :request do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://rspec.info/features/8-0/rspec-rails
  #
  # You can also this infer these behaviours automatically by location, e.g.
  # /spec/models would pull in the same behaviour as `type: :model` but this
  # behaviour is considered legacy and will be removed in a future version.
  #
  # To enable this behaviour uncomment the line below.
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")
  
  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods
  
  # Configure Capybara for JavaScript tests
  config.before(:each, js: true) do
    Capybara.current_driver = Capybara.javascript_driver
  end

  config.after(:each, js: true) do
    Capybara.use_default_driver
  end

  config.after(:each) do
    # Always clear ActionMailer deliveries
    ActionMailer::Base.deliveries.clear
  end

  # Configure shared database connection for system tests
  # This allows Capybara to see the same database state as the test thread
  config.after(:suite) do
    # Reset all sequences after test suite completes
    if ActiveRecord::Base.connection.adapter_name.downcase.include?('postgres')
      ActiveRecord::Base.connection.tables.each do |table|
        ActiveRecord::Base.connection.reset_pk_sequence!(table) rescue nil
      end
    end
  end

  config.before(:each, type: :system) do
    # Clear Rails cache
    Rails.cache.clear
    
    # Clear background job queues
    if ActiveJob::Base.queue_adapter.respond_to?(:enqueued_jobs)
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear
      ActiveJob::Base.queue_adapter.performed_jobs.clear rescue nil
    end
    
    # Ensure Capybara uses the correct driver
    driven_by(:selenium_chrome)
  end

  config.after(:each, type: :system) do
    # Reset Capybara session completely
    Capybara.reset_sessions!
    
    # Clear all browser data
    if page.driver.respond_to?(:browser)
      begin
        page.driver.browser.manage.delete_all_cookies
      rescue Selenium::WebDriver::Error::InvalidSessionIdError
        # Session already closed, ignore
      end
    end
    
    # Clear ActionMailer deliveries
    ActionMailer::Base.deliveries.clear
  end
end

# Configure shoulda-matchers
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
