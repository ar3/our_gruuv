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
      person.company_teammates.find_or_create_by!(organization: organization) do |t|
        t.first_employed_at = nil
        t.last_terminated_at = nil
      end
    else
      ct = person.active_teammates.first
      if ct.nil?
        person.company_teammates.create!(
          organization: Organization.find_by!(name: 'OurGruuv Demo'),
          first_employed_at: nil,
          last_terminated_at: nil
        )
      else
        ct
      end
    end
    
    # Stub current_company_teammate for request specs
    allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(teammate)
    
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

