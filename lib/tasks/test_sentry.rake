namespace :test do
  desc "Test Sentry logging functionality"
  task :sentry => :environment do
    puts "Testing Sentry logging..."
    
    # Test Rails.logger.error
    Rails.logger.error "This is a test error message from Rails.logger.error"
    
    # Test Sentry.capture_message directly
    Sentry.capture_message "This is a test message from Sentry.capture_message"
    
    # Test Sentry.capture_exception
    begin
      raise "This is a test exception"
    rescue => e
      Sentry.capture_exception(e)
    end
    
    puts "Test messages sent to Sentry. Check your Sentry dashboard."
  end
end 