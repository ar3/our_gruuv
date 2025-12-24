require 'rails_helper'

RSpec.describe 'Horizontal Navigation', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { CompanyTeammate.find_or_create_by!(person: person, organization: organization) }
  let(:user_preference) { UserPreference.for_person(person) }
  
  before do
    sign_in_as_teammate_for_request(person, organization)
    user_preference.update_preference(:layout, 'horizontal')
    # Mock policy for check-ins visibility
    allow_any_instance_of(CompanyTeammatePolicy).to receive(:view_check_ins?).and_return(true)
    # Mock OrganizationPolicy view methods for navigation and controller authorization
    allow_any_instance_of(OrganizationPolicy).to receive(:view_prompts?).and_return(true)
    allow_any_instance_of(OrganizationPolicy).to receive(:view_prompt_templates?).and_return(true)
    allow_any_instance_of(OrganizationPolicy).to receive(:view_observations?).and_return(true)
    allow_any_instance_of(OrganizationPolicy).to receive(:view_seats?).and_return(true)
    allow_any_instance_of(OrganizationPolicy).to receive(:view_goals?).and_return(true)
    allow_any_instance_of(OrganizationPolicy).to receive(:view_abilities?).and_return(true)
    allow_any_instance_of(OrganizationPolicy).to receive(:view_assignments?).and_return(true)
    allow_any_instance_of(OrganizationPolicy).to receive(:view_aspirations?).and_return(true)
    allow_any_instance_of(OrganizationPolicy).to receive(:view_bulk_sync_events?).and_return(true)
    allow_any_instance_of(OrganizationPolicy).to receive(:show?).and_return(true)
    allow_any_instance_of(OrganizationPolicy).to receive(:manage_employment?).and_return(true)
  end
  
  describe 'header links' do
    it 'links navbar brand to about me page' do
      get dashboard_organization_path(organization)
      
      expect(response).to have_http_status(:success)
      about_me_path = about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include("href=\"#{about_me_path}\"")
      
      # Check that the navbar-brand links to about me
      navbar_brand = response.body[/<a[^>]*class="[^"]*navbar-brand[^"]*"[^>]*href="#{Regexp.escape(about_me_path)}"[^>]*>/]
      expect(navbar_brand).to be_present
    end
  end
end

