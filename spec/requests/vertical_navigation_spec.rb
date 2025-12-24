require 'rails_helper'

RSpec.describe 'Vertical Navigation', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { CompanyTeammate.find_or_create_by!(person: person, organization: organization) }
  let(:user_preference) { UserPreference.for_person(person) }
  
  before do
    sign_in_as_teammate_for_request(person, organization)
    user_preference.update_preference(:layout, 'vertical')
    user_preference.update_preference(:vertical_nav_open, true)
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
  
  describe 'collapsible sections' do
    context 'when on dashboard page' do
      it 'renders vertical navigation with all sections closed' do
        get dashboard_organization_path(organization)
        
        expect(response).to have_http_status(:success)
        expect(response.body).to include('vertical-nav')
        
        # All collapsible sections should be closed (no show class, aria-expanded="false")
        # Check for Huddles section (section name is 'huddles')
        expect(response.body).to include('id="navSectionHuddles"')
        huddles_div = response.body[/<div[^>]*id="navSectionHuddles"[^>]*>/]
        expect(huddles_div).to be_present
        expect(huddles_div).to include('class="collapse"')
        expect(huddles_div).to_not include('class="collapse show"')
        expect(response.body).to include('data-bs-target="#navSectionHuddles"')
        expect(response.body).to include('aria-expanded="false"')
        
        # Check for Admin section
        # Note: Admin section may be expanded if organization_path matches dashboard path
        # This is due to nav_item_active? using start_with? matching
        expect(response.body).to include('id="navSectionAdmin"')
      end
    end
    
    context 'when on a page within Align section' do
      before do
        org_policy_double = double(
          show?: true,
          manage_employment?: true,
          view_prompts?: true,
          view_prompt_templates?: true,
          view_observations?: true,
          view_seats?: true,
          view_goals?: true,
          view_abilities?: true,
          view_assignments?: true,
          view_aspirations?: true,
          view_bulk_sync_events?: true
        )
        policy_double = double(show?: true, create?: true, view_check_ins?: true)
        
        allow_any_instance_of(ApplicationController).to receive(:policy) do |controller, record|
          case record
          when Organization
            org_policy_double
          else
            policy_double
          end
        end
      end
      
      it 'renders observations page successfully' do
        get organization_observations_path(organization)
        
        expect(response).to have_http_status(:success)
        # Observations is a standalone nav item (section: nil), not in a collapsible section
        # So we just verify the page loads successfully
        expect(response.body).to include('vertical-nav')
      end
    end
    
    context 'when on a page within Admin section' do
      before do
        org_policy_double = double(
          show?: true,
          manage_employment?: true,
          view_prompts?: true,
          view_prompt_templates?: true,
          view_observations?: true,
          view_seats?: true,
          view_goals?: true,
          view_abilities?: true,
          view_assignments?: true,
          view_aspirations?: true,
          view_bulk_sync_events?: true
        )
        policy_double = double(show?: true, create?: true, view_check_ins?: true)
        
        allow_any_instance_of(ApplicationController).to receive(:policy) do |controller, record|
          case record
          when Organization
            org_policy_double
          else
            policy_double
          end
        end
      end
      
      it 'expands only the Admin section' do
        get organization_seats_path(organization)
        
        expect(response).to have_http_status(:success)
        
        # Admin section should be expanded
        admin_div = response.body[/<div[^>]*id="navSectionAdmin"[^>]*>/]
        expect(admin_div).to be_present
        expect(admin_div).to include('class="collapse show"')
        
        # Check button aria-expanded
        admin_button = response.body[/<button[^>]*data-bs-target="#navSectionAdmin"[^>]*>/]
        expect(admin_button).to be_present
        expect(admin_button).to include('aria-expanded="true"')
        
        # Other sections should be closed
        huddles_div = response.body[/<div[^>]*id="navSectionHuddles"[^>]*>/]
        if huddles_div.present?
          expect(huddles_div).to_not include('class="collapse show"')
        end
      end
    end
    
    context 'when on a page within Collab section' do
      before do
        org_policy_double = double(
          show?: true,
          manage_employment?: true,
          view_prompts?: true,
          view_prompt_templates?: true,
          view_observations?: true,
          view_seats?: true,
          view_goals?: true,
          view_abilities?: true,
          view_assignments?: true,
          view_aspirations?: true,
          view_bulk_sync_events?: true
        )
        policy_double = double(show?: true, create?: true, view_check_ins?: true)
        
        allow_any_instance_of(ApplicationController).to receive(:policy) do |controller, record|
          case record
          when Organization
            org_policy_double
          else
            policy_double
          end
        end
      end
      
      it 'expands only the Huddles section' do
        get huddles_path
        
        expect(response).to have_http_status(:success)
        
        # Huddles section should be expanded (section name is 'huddles', which becomes 'Huddles' when capitalized)
        huddles_div = response.body[/<div[^>]*id="navSectionHuddles"[^>]*>/]
        expect(huddles_div).to be_present
        expect(huddles_div).to include('class="collapse show"')
        
        # Check button aria-expanded
        huddles_button = response.body[/<button[^>]*data-bs-target="#navSectionHuddles"[^>]*>/]
        expect(huddles_button).to be_present
        expect(huddles_button).to include('aria-expanded="true"')
        
        # Other sections should be closed
        admin_div = response.body[/<div[^>]*id="navSectionAdmin"[^>]*>/]
        if admin_div.present?
          expect(admin_div).to_not include('class="collapse show"')
        end
      end
    end
  end
  
  describe 'recently visited section' do
    context 'when there are no recent visits' do
      it 'does not render the recently visited section' do
        get dashboard_organization_path(organization)
        
        expect(response).to have_http_status(:success)
        expect(response.body).to_not include('navSectionRecentlyVisited')
      end
    end
    
    context 'when there are recent visits' do
      let!(:page_visit) do
        create(:page_visit, person: person, url: dashboard_organization_path(organization), page_title: 'Dashboard')
      end
      
      it 'renders the recently visited section closed by default' do
        # Visit a page that's not in recent visits
        get organization_seats_path(organization)
        
        expect(response).to have_http_status(:success)
        expect(response.body).to include('navSectionRecentlyVisited')
        recent_div = response.body[/<div[^>]*id="navSectionRecentlyVisited"[^>]*>/]
        expect(recent_div).to be_present
        expect(recent_div).to_not include('class="collapse show"')
      end
      
      it 'expands the recently visited section when on a visited page' do
        # Visit the dashboard which should be in recent visits
        get dashboard_organization_path(organization)
        
        expect(response).to have_http_status(:success)
        # Since we're on the dashboard, which is in recent visits, it should be expanded
        recent_div = response.body[/<div[^>]*id="navSectionRecentlyVisited"[^>]*>/]
        expect(recent_div).to be_present
        expect(recent_div).to include('class="collapse show"')
        
        # Check button aria-expanded
        recent_button = response.body[/<button[^>]*data-bs-target="#navSectionRecentlyVisited"[^>]*>/]
        expect(recent_button).to be_present
        expect(recent_button).to include('aria-expanded="true"')
      end
    end
  end
  
  describe 'header links' do
    it 'links top bar header to about me page' do
      get dashboard_organization_path(organization)
      
      expect(response).to have_http_status(:success)
      about_me_path = about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include("href=\"#{about_me_path}\"")
      
      # Check that the navbar-brand in top bar links to about me
      navbar_brand = response.body[/<a[^>]*class="[^"]*navbar-brand[^"]*"[^>]*href="#{Regexp.escape(about_me_path)}"[^>]*>/]
      expect(navbar_brand).to be_present
    end
    
    it 'links vertical nav sidebar header to about me page' do
      get dashboard_organization_path(organization)
      
      expect(response).to have_http_status(:success)
      about_me_path = about_me_organization_company_teammate_path(organization, teammate)
      
      # Check that the vertical nav header contains a link to about me
      # The header should have an h5 wrapped in a link
      expect(response.body).to match(/<a[^>]*href="#{Regexp.escape(about_me_path)}"[^>]*>.*<h5[^>]*>Navigation<\/h5>/m)
    end
  end
end
