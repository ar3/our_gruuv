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
    allow_any_instance_of(OrganizationPolicy).to receive(:customize_company?).and_return(true)
    # Mock CompanyPolicy (inherits from OrganizationPolicy, but Pundit will use CompanyPolicy for current_company)
    allow_any_instance_of(CompanyPolicy).to receive(:view_prompts?).and_return(true)
    allow_any_instance_of(CompanyPolicy).to receive(:view_prompt_templates?).and_return(true)
    allow_any_instance_of(CompanyPolicy).to receive(:view_observations?).and_return(true)
    allow_any_instance_of(CompanyPolicy).to receive(:view_seats?).and_return(true)
    allow_any_instance_of(CompanyPolicy).to receive(:view_goals?).and_return(true)
    allow_any_instance_of(CompanyPolicy).to receive(:view_abilities?).and_return(true)
    allow_any_instance_of(CompanyPolicy).to receive(:view_assignments?).and_return(true)
    allow_any_instance_of(CompanyPolicy).to receive(:view_aspirations?).and_return(true)
    allow_any_instance_of(CompanyPolicy).to receive(:view_bulk_sync_events?).and_return(true)
    allow_any_instance_of(CompanyPolicy).to receive(:customize_company?).and_return(true)
    # Mock Huddle policy
    allow_any_instance_of(HuddlePolicy).to receive(:show?).and_return(true)
  end
  
  describe 'header links' do
    it 'links navbar brand to about me page' do
      get dashboard_organization_path(organization)
      follow_redirect! if response.redirect?
      
      expect(response).to have_http_status(:success)
      about_me_path = about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include("href=\"#{about_me_path}\"")
      
      # Check that the navbar-brand links to about me
      navbar_brand = response.body[/<a[^>]*class="[^"]*navbar-brand[^"]*"[^>]*href="#{Regexp.escape(about_me_path)}"[^>]*>/]
      expect(navbar_brand).to be_present
    end
  end
  
  describe 'dropdown menus' do
    before do
      get dashboard_organization_path(organization)
      follow_redirect! if response.redirect?
      expect(response).to have_http_status(:success)
    end
    
    it 'displays Clarity dropdown' do
      expect(response.body).to include('Clarity')
      expect(response.body).to match(/<a[^>]*>\s*Clarity\s*<\/a>/m)
    end
    
    it 'displays Challenge dropdown' do
      expect(response.body).to include('Challenge')
      expect(response.body).to match(/<a[^>]*>\s*Challenge\s*<\/a>/m)
    end
    
    it 'displays Continuous Feedback dropdown' do
      expect(response.body).to include('Continuous Feedback')
      expect(response.body).to match(/<a[^>]*>\s*Continuous Feedback\s*<\/a>/m)
    end
    
    it 'displays Admin dropdown' do
      expect(response.body).to include('Admin')
      expect(response.body).to match(/<a[^>]*>\s*Admin\s*<\/a>/m)
    end
    
    it 'does not display old Align dropdown' do
      expect(response.body).not_to match(/<a[^>]*>\s*Align\s*<\/a>/m)
    end
    
    it 'does not display old Collab dropdown' do
      expect(response.body).not_to match(/<a[^>]*>\s*Collab\s*<\/a>/m)
    end
    
    it 'does not display old Transform dropdown' do
      expect(response.body).not_to match(/<a[^>]*>\s*Transform\s*<\/a>/m)
    end
  end
  
  describe 'Clarity dropdown links' do
    before do
      get dashboard_organization_path(organization)
      follow_redirect! if response.redirect?
      expect(response).to have_http_status(:success)
    end
    
    it 'includes Positions link' do
      expect(response.body).to include('Positions')
      expect(response.body).to include(organization_positions_path(organization))
    end
    
    it 'includes Assignments link' do
      expect(response.body).to include('Assignments')
      expect(response.body).to include(organization_assignments_path(organization))
    end
    
    it 'includes View Teammates link' do
      expect(response.body).to include('View Teammates')
      expect(response.body).to include(organization_employees_path(organization))
    end
    
    it 'includes Goals link' do
      expect(response.body).to include('Goals')
      expect(response.body).to include(organization_goals_path(organization))
    end
    
    it 'includes Abilities link' do
      expect(response.body).to include('Abilities')
      expect(response.body).to include(organization_abilities_path(organization))
    end
    
    it 'includes Accountability link' do
      expect(response.body).to include('Accountability')
      expect(response.body).to include(accountability_path)
    end
  end
  
  describe 'Challenge dropdown links' do
    before do
      get dashboard_organization_path(organization)
      follow_redirect! if response.redirect?
      expect(response).to have_http_status(:success)
    end
    
    it 'includes Celebrate Milestones link' do
      expect(response.body).to include('Celebrate Milestones')
      expect(response.body).to include(celebrate_milestones_organization_path(organization))
    end
    
    it 'includes Hypotheses link with Coming Soon badge' do
      expect(response.body).to include('Hypotheses')
      expect(response.body).to include(hypothesis_management_coming_soon_path)
      expect(response.body).to include('Coming Soon')
    end
    
    it 'includes OKR3s link with Coming Soon badge' do
      expect(response.body).to include('OKR3s')
      expect(response.body).to include(okr3_management_coming_soon_path)
    end
    
    it 'includes Signals link with Coming Soon badge' do
      expect(response.body).to include('Signals')
      expect(response.body).to include(team_signals_coming_soon_path)
    end
  end
  
  describe 'Continuous Feedback dropdown links' do
    before do
      get dashboard_organization_path(organization)
      follow_redirect! if response.redirect?
      expect(response).to have_http_status(:success)
    end
    
    it 'includes About Me link' do
      expect(response.body).to include('About Me')
      expect(response.body).to include(about_me_organization_company_teammate_path(organization, teammate))
    end
    
    it 'includes My Check-In link' do
      expect(response.body).to include('My Check-In')
      expect(response.body).to include(organization_company_teammate_check_ins_path(organization, teammate))
    end
    
    it 'includes Observations link' do
      expect(response.body).to include('Observations')
      expect(response.body).to include(organization_observations_path(organization))
    end
    
    it 'includes Huddles links' do
      expect(response.body).to include("Huddle Review")
      expect(response.body).to include("My Huddles")
      # HTML entity for apostrophe is &#39;
      expect(response.body).to match(/Today(&#39;|')s Huddles/)
    end
  end
  
  describe 'Admin dropdown links' do
    before do
      get dashboard_organization_path(organization)
      follow_redirect! if response.redirect?
      expect(response).to have_http_status(:success)
    end
    
    it 'includes Slack Settings link' do
      expect(response.body).to include('Slack Settings')
      expect(response.body).to include(organization_slack_path(organization))
    end
    
    it 'includes Huddle Playbooks link' do
      expect(response.body).to include('Huddle Playbooks')
      expect(response.body).to include(organization_huddle_playbooks_path(organization))
    end
    
    it 'includes Check-ins Health link' do
      expect(response.body).to include('Check-ins Health')
      expect(response.body).to include(organization_check_ins_health_path(organization))
    end
    
    it 'includes Help Improve OG link' do
      expect(response.body).to include('Help Improve OG')
      expect(response.body).to include(interest_submissions_path)
    end
  end
end

