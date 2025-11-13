# spec/support/request_authentication_helpers.rb
module RequestAuthenticationHelpers
  # Sign in a person as a teammate for request specs
  # Creates or finds a Teammate for the person and organization, then stubs current_company_teammate
  # 
  # @param person [Person] The person to sign in
  # @param organization [Organization, nil] The organization to sign in to. If nil, uses first active teammate or creates "OurGruuv Demo" teammate
  # @return [Teammate] The teammate that was signed in
  def sign_in_as_teammate_for_request(person, organization = nil)
    # Find or create teammate for the specified organization
    teammate = if organization
      # Find existing teammate or create new one
      existing_teammate = person.teammates.find_by(organization: organization)
      if existing_teammate
        # Ensure it's a CompanyTeammate - update type if needed
        if existing_teammate.type != 'CompanyTeammate'
          existing_teammate.update_column(:type, 'CompanyTeammate')
          existing_teammate = existing_teammate.reload
        end
        existing_teammate
      else
        # Create new CompanyTeammate
        person.teammates.create!(
          organization: organization,
          type: 'CompanyTeammate',
          first_employed_at: nil,
          last_terminated_at: nil
        )
      end
    else
      # Use first active teammate or create "OurGruuv Demo" teammate
      teammate = person.active_teammates.first
      if teammate.nil?
        teammate = person.teammates.create!(
          organization: Company.find_by!(name: 'OurGruuv Demo'),
          type: 'CompanyTeammate',
          first_employed_at: nil,
          last_terminated_at: nil
        )
      end
      # Ensure it's a CompanyTeammate
      if teammate.type != 'CompanyTeammate'
        teammate.update_column(:type, 'CompanyTeammate')
        teammate = teammate.reload
      end
      teammate
    end
    
    # Stub current_company_teammate for request specs
    allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(teammate)
    
    # Stub real_current_teammate for admin bypass checks
    allow_any_instance_of(ApplicationController).to receive(:real_current_teammate).and_return(teammate)
    
    # Also stub current_person and current_organization for backward compatibility
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(teammate.person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(teammate.organization)
    
    teammate
  end
  
  # Sign out the current teammate
  def sign_out_teammate_for_request
    allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(nil)
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(nil)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(nil)
  end
end

RSpec.configure do |config|
  config.include RequestAuthenticationHelpers, type: :request
end

