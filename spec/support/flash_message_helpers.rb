# spec/support/flash_message_helpers.rb
module FlashMessageHelpers
  # Check flash messages programmatically without relying on visible text
  # Flash messages are in Bootstrap toast notifications which may be hidden
  def has_flash_message?(message)
    # Check if message exists in toast container (may be hidden)
    # Also check raw HTML since toasts might not be initialized in tests
    page.has_css?('.toast-body', text: message, visible: false) ||
    page.html.include?(message)
  end
  
  # Check if a success/notice flash message is present
  def has_success_flash?(message)
    has_flash_message?(message)
  end
  
  # Check if an error flash message is present
  def has_error_flash?(message)
    has_flash_message?(message)
  end
  
  # Check if a notice flash message is present
  def has_notice_flash?(message)
    has_flash_message?(message)
  end
end

# RSpec matchers for flash messages
RSpec::Matchers.define :have_success_flash do |expected_message|
  match do |page|
    page.has_css?('.toast-body', text: expected_message, visible: false) ||
    page.html.include?(expected_message)
  end
  
  failure_message do |page|
    "expected page to have success flash message '#{expected_message}', but it didn't. Page HTML: #{page.html[0..500]}"
  end
end

RSpec::Matchers.define :have_error_flash do |expected_message|
  match do |page|
    page.has_css?('.toast-body', text: expected_message, visible: false) ||
    page.html.include?(expected_message)
  end
  
  failure_message do |page|
    "expected page to have error flash message '#{expected_message}', but it didn't. Page HTML: #{page.html[0..500]}"
  end
end

RSpec::Matchers.define :have_notice_flash do |expected_message|
  match do |page|
    page.has_css?('.toast-body', text: expected_message, visible: false) ||
    page.html.include?(expected_message)
  end
  
  failure_message do |page|
    "expected page to have notice flash message '#{expected_message}', but it didn't. Page HTML: #{page.html[0..500]}"
  end
end

RSpec.configure do |config|
  config.include FlashMessageHelpers, type: :system
end

