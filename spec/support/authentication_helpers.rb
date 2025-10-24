# spec/support/authentication_helpers.rb
module AuthenticationHelpers
  def sign_in_as(person, organization = nil)
    # For JavaScript tests (Selenium), use HTTP endpoint since rack_session_access doesn't work
    if Capybara.current_driver == Capybara.javascript_driver
      sign_in_via_http(person, organization)
    else
      # For non-JS tests, use rack_session_access
      # First, clear any existing session to avoid conflicts
      begin
        page.set_rack_session(current_person_id: nil)
        page.set_rack_session(current_person_id: person.id)
      rescue Selenium::WebDriver::Error::UnknownError, Selenium::WebDriver::Error::InvalidSessionIdError
        # If session is invalid, visit a page first to establish it
        visit root_path
        page.set_rack_session(current_person_id: nil)
        page.set_rack_session(current_person_id: person.id)
      end
      
      # Also set the organization if provided
      if organization
        person.update!(current_organization: organization)
      end
      
      # Ensure the person is properly set up
      person.reload
    end
  end
  
  def sign_out
    if Capybara.current_driver == Capybara.javascript_driver
      sign_out_via_http
    else
      page.set_rack_session(current_person_id: nil)
    end
  end
  
  # Helper for system tests that need to switch users mid-test
  def switch_to_user(person, organization = nil)
    # Clear any existing session
    sign_out
    
    # Set new session
    sign_in_as(person, organization)
  end
  
  private
  
  def sign_in_via_http(person, organization = nil)
    params = { person_id: person.id }
    params[:organization_id] = organization.id if organization
    
    # Use Capybara's visit method with query parameters
    query_string = params.map { |k, v| "#{k}=#{v}" }.join('&')
    puts "\n=== DEBUG: Signing in via HTTP: /test/auth/sign_in?#{query_string} ==="
    visit("/test/auth/sign_in?#{query_string}")
    puts "=== DEBUG: Response: #{page.text[0..200]} ==="
    
    # Wait for the request to complete
    sleep(0.1)
    
    # Ensure the person is properly set up
    person.reload
  end
  
  def sign_in_and_visit(person, organization, target_path)
    params = { 
      person_id: person.id,
      organization_id: organization.id,
      redirect_to: target_path
    }
    
    # Use Capybara's visit method with query parameters
    query_string = params.map { |k, v| "#{k}=#{v}" }.join('&')
    visit("/test/auth/sign_in?#{query_string}")
    
    # Ensure the person is properly set up
    person.reload
  end
  
  def sign_out_via_http
    visit('/test/auth/sign_out')
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :system
end
