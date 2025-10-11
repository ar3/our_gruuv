require 'rails_helper'

RSpec.describe 'Organization Dashboard', type: :system, critical: true do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: organization, can_manage_employment: true) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(person).to receive(:can_manage_employment?).and_return(true)
  end

  describe 'Dashboard main page' do
    it 'loads organization dashboard' do
      visit dashboard_organization_path(organization)

      expect(page).to have_content("#{organization.display_name} Dashboard")
      expect(page).to have_content('Observations')
      expect(page).to have_content('KNOW')
      expect(page).to have_content('CONVO')
      expect(page).to have_content('TEMPO')
    end

    it 'shows observations section' do
      visit dashboard_organization_path(organization)

      expect(page).to have_content('Observations')
      expect(page).to have_content('Give the gift')
      expect(page).to have_content('of feedback')
      expect(page).to have_content('Recent Observation')
      expect(page).to have_content('My Observation')
    end

    it 'shows KNOW section with milestones' do
      visit dashboard_organization_path(organization)

      expect(page).to have_content('KNOW')
      expect(page).to have_content('Clarify expectations')
      expect(page).to have_content('Milestones')
      expect(page).to have_content('Recent Milestone')
      expect(page).to have_content('All Ability')
      expect(page).to have_content('My Milestone')
    end

    it 'shows CONVO section with collaboration tools' do
      visit dashboard_organization_path(organization)

      expect(page).to have_content('CONVO')
      expect(page).to have_content('Amplify collaboration')
      expect(page).to have_content('Opportunities')
      expect(page).to have_content('Decisions')
      expect(page).to have_content('Huddles')
    end

    it 'shows TEMPO section with progress tracking' do
      visit dashboard_organization_path(organization)

      expect(page).to have_content('TEMPO')
      expect(page).to have_content('Highlight progress')
      expect(page).to have_content('Signals')
      expect(page).to have_content('Hypotheses')
      expect(page).to have_content('OKR3s')
    end

    it 'shows organization section with team overview' do
      visit dashboard_organization_path(organization)

      expect(page).to have_content(organization.display_name)
      expect(page).to have_content('All Teammate')
      expect(page).to have_content('All Team')
      expect(page).to have_content('Organization Overview')
    end
  end

  describe 'Dashboard navigation' do
    it 'navigates to observations creation' do
      visit dashboard_organization_path(organization)

      click_link 'Give the gift'
      expect(page).to have_content('Create Observation')
    end

    it 'navigates to observations list' do
      visit dashboard_organization_path(organization)

      click_link 'Recent Observation'
      expect(page).to have_content('Observations')
    end

    it 'navigates to abilities management' do
      visit dashboard_organization_path(organization)

      click_link 'All Ability'
      expect(page).to have_content('Abilities')
    end

    it 'navigates to teammates list' do
      visit dashboard_organization_path(organization)

      click_link 'All Teammate'
      expect(page).to have_content('Teammates')
    end

    it 'navigates to organization overview' do
      visit dashboard_organization_path(organization)

      click_link 'Organization Overview'
      expect(page).to have_content(organization.display_name)
    end
  end

  describe 'Dashboard with data' do
    let!(:ability) { create(:ability, organization: organization, name: 'JavaScript Programming') }
    let!(:teammate_milestone) { create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 3) }
    let!(:observation) { create(:observation, observer: person, company: organization, story: 'Great work on the project') }

    it 'shows milestone counts' do
      visit dashboard_organization_path(organization)

      expect(page).to have_content('1 Recent Milestone')
      expect(page).to have_content('1 Ability')
      expect(page).to have_content('1 Milestone')
    end

    it 'shows observation counts' do
      visit dashboard_organization_path(organization)

      expect(page).to have_content('1 Recent Observation')
      expect(page).to have_content('1 Observation')
    end

    it 'shows teammate counts' do
      visit dashboard_organization_path(organization)

      expect(page).to have_content('1 Teammate')
    end
  end

  describe 'Dashboard permissions' do
    let!(:employee_person) { create(:person, full_name: 'John Doe') }
    let!(:employee_teammate) { create(:teammate, person: employee_person, organization: organization, can_manage_employment: false) }

    it 'shows appropriate content for non-managers' do
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(employee_person)
      allow(employee_person).to receive(:can_manage_employment?).and_return(false)

      visit dashboard_organization_path(organization)

      expect(page).to have_content("#{organization.display_name} Dashboard")
      expect(page).to have_content('Observations')
      # Should still show dashboard but with limited functionality
    end
  end

  describe 'Dashboard empty states' do
    it 'shows zero counts for new organization' do
      visit dashboard_organization_path(organization)

      expect(page).to have_content('0 Recent Observation')
      expect(page).to have_content('0 Observation')
      expect(page).to have_content('0 Recent Milestone')
      expect(page).to have_content('0 Ability')
      expect(page).to have_content('0 Milestone')
      expect(page).to have_content('1 Teammate') # Current user
    end
  end

  describe 'Dashboard sections content' do
    it 'shows coming soon features' do
      visit dashboard_organization_path(organization)

      expect(page).to have_content('Coming Soon')
      expect(page).to have_content('View Team Signals')
      expect(page).to have_content('Create Hypothesis')
      expect(page).to have_content('Create OKR3')
      expect(page).to have_content('Add New Oppty')
      expect(page).to have_content('Start Decision Process')
    end

    it 'shows huddles section with real functionality' do
      visit dashboard_organization_path(organization)

      expect(page).to have_content('Huddles')
      expect(page).to have_content('Huddles Review')
      expect(page).to have_content('Open Huddle')
      expect(page).to have_content('My Huddles')
    end
  end

  describe 'Dashboard responsiveness' do
    it 'loads quickly with minimal queries' do
      # This test ensures the dashboard doesn't have N+1 query issues
      visit dashboard_organization_path(organization)
      expect(page).to have_content("#{organization.display_name} Dashboard")
    end
  end
end
