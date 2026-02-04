# spec/support/authentication_helpers.rb
module AuthenticationHelpers
  def sign_in_as(person, organization = nil)
    # Ensure person has a teammate
    teammate = person.active_teammates.first
    if organization
      # Find or create teammate for the specified organization
      teammate = person.company_teammates.find_or_create_by!(organization: organization) do |t|
        t.first_employed_at = nil
        t.last_terminated_at = nil
      end
    else
      # Use first active teammate or create "OurGruuv Demo" teammate
      teammate ||= person.teammates.create!(
        organization: Organization.find_by!(name: 'OurGruuv Demo'),
        type: 'CompanyTeammate',
        first_employed_at: nil,
        last_terminated_at: nil
      )
    end
    
    # For JavaScript tests (Selenium), use HTTP endpoint since rack_session_access doesn't work
    if Capybara.current_driver == Capybara.javascript_driver
      sign_in_via_http(teammate)
    else
      # For non-JS tests, use rack_session_access
      # First, clear any existing session to avoid conflicts
      begin
        page.set_rack_session(current_company_teammate_id: nil)
        page.set_rack_session(current_company_teammate_id: teammate.id)
      rescue Selenium::WebDriver::Error::UnknownError, Selenium::WebDriver::Error::InvalidSessionIdError
        # If session is invalid, visit a page first to establish it
        visit root_path
        page.set_rack_session(current_company_teammate_id: nil)
        page.set_rack_session(current_company_teammate_id: teammate.id)
      end
      
      # Ensure the teammate is properly set up
      teammate.reload
    end
  end
  
  def sign_out
    if Capybara.current_driver == Capybara.javascript_driver
      sign_out_via_http
    else
      page.set_rack_session(current_company_teammate_id: nil)
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
  
  def sign_in_via_http(teammate)
    params = { teammate_id: teammate.id }
    
    # Use Capybara's visit method with query parameters
    query_string = params.map { |k, v| "#{k}=#{v}" }.join('&')
    visit("/test/auth/sign_in?#{query_string}")
    
    # Wait for the request to complete
    sleep(0.1)
    
    # Ensure the teammate is properly set up
    teammate.reload
  end
  
  def sign_in_and_visit(person, organization, target_path)
    # Ensure person has a teammate for the organization
    teammate = person.company_teammates.find_or_create_by!(organization: organization) do |t|
      t.first_employed_at = nil
      t.last_terminated_at = nil
    end
    
    params = { 
      teammate_id: teammate.id,
      redirect_to: target_path
    }
    
    # Use Capybara's visit method with query parameters
    query_string = params.map { |k, v| "#{k}=#{v}" }.join('&')
    visit("/test/auth/sign_in?#{query_string}")
    
    # Ensure the teammate is properly set up
    teammate.reload
  end
  
  def sign_out_via_http
    visit('/test/auth/sign_out')
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :system
end
