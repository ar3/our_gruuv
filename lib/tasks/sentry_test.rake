namespace :sentry do
  desc "Test Sentry integration by generating test errors"
  task test: :environment do
    puts "Testing Sentry integration..."
    
    # Test 1: Capture a simple message
    puts "1. Testing message capture..."
    Sentry.capture_message("Test message from Rake task", level: :info)
    
    # Test 2: Capture an exception
    puts "2. Testing exception capture..."
    begin
      raise "Test exception from Rake task"
    rescue => e
      Sentry.capture_exception(e)
    end
    
    # Test 3: Test with context
    puts "3. Testing with context..."
    Sentry.capture_message("Test message with context", level: :warning) do |event|
      event.set_context('rake_task', {
        task_name: 'sentry:test',
        timestamp: Time.current.iso8601
      })
    end
    
    puts "Sentry test completed! Check your Sentry dashboard for these test events."
  end
end 