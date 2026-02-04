# spec/support/controller_authentication_helpers.rb
module ControllerAuthenticationHelpers
  # Sign in a person as a teammate for controller specs
  # Creates or finds a Teammate for the person and organization, then sets the session
  # 
  # @param person [Person] The person to sign in
  # @param organization [Organization, nil] The organization to sign in to. If nil, uses first active teammate or creates "OurGruuv Demo" teammate
  # @return [Teammate] The teammate that was signed in
  def sign_in_as_teammate(person, organization = nil)
    # Find or create teammate for the specified organization
    teammate = if organization
      # Check if teammate already exists first to avoid validation errors
      person.teammates.find_by(organization: organization) ||
        person.teammates.create!(
          organization: organization,
          first_employed_at: nil,
          last_terminated_at: nil
        )
    else
      # Use first active teammate or create "OurGruuv Demo" teammate
      teammate = person.active_teammates.first
      if teammate.nil?
        teammate = person.teammates.create!(
          organization: Organization.find_by!(name: 'OurGruuv Demo'),
          first_employed_at: nil,
          last_terminated_at: nil
        )
      end
    end
    
    # Set the session for controller specs
    session[:current_company_teammate_id] = teammate.id
    
    # Clear any cached teammate so it reloads
    @current_company_teammate = nil if defined?(@current_company_teammate)
    
    teammate
  end
  
  # Sign out the current teammate
  def sign_out_teammate
    session.delete(:current_company_teammate_id)
    @current_company_teammate = nil if defined?(@current_company_teammate)
  end
end

RSpec.configure do |config|
  config.include ControllerAuthenticationHelpers, type: :controller
end

