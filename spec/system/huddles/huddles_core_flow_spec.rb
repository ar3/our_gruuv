require 'rails_helper'

RSpec.describe 'Huddles Core Flow', type: :system do
  let(:company) { create(:organization, :company) }
  let(:department) { create(:department, company: company) }
  let(:team) { create(:team, company: company) }
  let(:person) { create(:person, full_name: 'User') }
  let!(:teammate) { CompanyTeammate.create!(person: person, organization: company) }

  before do
    sign_in_as(person, company)
  end

  describe 'Create huddle from existing company, department, or team' do
    let!(:existing_team) { create(:team, company: company, name: 'Existing Team') }
    let!(:department_as_team) { create(:team, company: company, name: department.name) }
    
    it 'creates huddle from existing company' do
      # UI: cards per company with list of teams; click "Start Huddle" for a team
      initial_huddle_count = Huddle.count
      visit new_huddle_path(organization_id: company.id)
      
      expect(page).to have_content(company.name)
      # Use first() to avoid ambiguous match when multiple cards/list items exist
      first('.list-group-item', text: existing_team.name).click_button('Start Huddle')
      
      sleep 1
      
      expect(Huddle.count).to eq(initial_huddle_count + 1)
      huddle = Huddle.last
      expect(huddle).to be_present
      expect(huddle.team.id).to eq(existing_team.id)
      
      # Approach 2: Check for huddle creation in database
      # visit new_huddle_path(organization_id: company.id)
      # expect(page).to have_content(company.name)
      # fill_in 'huddle_name', with: 'Company Huddle'
      # click_button 'Start Huddle'
      # huddle = Huddle.last
      # expect(huddle.name).to eq('Company Huddle')
      # expect(huddle.team.organization).to eq(company)
      
      # Approach 3: Check for redirect to huddle page
      # visit new_huddle_path(organization_id: company.id)
      # expect(page).to have_content(company.name)
      # fill_in 'huddle_name', with: 'Company Huddle'
      # click_button 'Start Huddle'
      # expect(page.current_path).to include('huddles')
      # expect(page).to have_content('Company Huddle')
    end

    it 'creates huddle from existing department' do
      # Department belongs to company; UI shows company cards with teams
      initial_huddle_count = Huddle.count
      visit new_huddle_path(organization_id: department.id)
      
      expect(page).to have_content(department.company.name)
      first('.list-group-item', text: department_as_team.name).click_button('Start Huddle')
      
      sleep 1
      
      expect(Huddle.count).to eq(initial_huddle_count + 1)
      huddle = Huddle.last
      expect(huddle).to be_present
      expect(huddle.team.id).to eq(department_as_team.id)
      
      # Approach 2: Check for huddle creation in database
      # visit new_huddle_path(organization_id: department.id)
      # expect(page).to have_content(department.name)
      # fill_in 'huddle_name', with: 'Department Huddle'
      # click_button 'Start Huddle'
      # huddle = Huddle.last
      # expect(huddle.name).to eq('Department Huddle')
      
      # Approach 3: Check for redirect
      # visit new_huddle_path(organization_id: department.id)
      # expect(page).to have_content(department.name)
      # fill_in 'huddle_name', with: 'Department Huddle'
      # click_button 'Start Huddle'
      # expect(page.current_path).to include('huddles')
    end

    it 'creates huddle from existing team' do
      initial_huddle_count = Huddle.count
      visit new_huddle_path(organization_id: team.id)
      expect(page).to have_content(team.company.name)
      first('.list-group-item', text: team.name).click_button('Start Huddle')
      sleep 1
      expect(Huddle.count).to eq(initial_huddle_count + 1)
      huddle = Huddle.last
      expect(huddle).to be_present
      expect(huddle.team.id).to eq(team.id)
      
      # Approach 2: Check for huddle creation in database
      # visit new_huddle_path(organization_id: team.id)
      # expect(page).to have_content(team.name)
      # fill_in 'huddle_name', with: 'Team Huddle'
      # click_button 'Start Huddle'
      # huddle = Huddle.last
      # expect(huddle.name).to eq('Team Huddle')
      
      # Approach 3: Check for redirect
      # visit new_huddle_path(organization_id: team.id)
      # expect(page).to have_content(team.name)
      # fill_in 'huddle_name', with: 'Team Huddle'
      # click_button 'Start Huddle'
      # expect(page.current_path).to include('huddles')
    end
  end

  describe 'Create huddle and create new team in huddle creation flow' do
    xit 'creates new team during huddle creation' do
      # New huddle UI no longer has Company/Team dropdowns or "Create new team" - it shows cards with existing teams only
      initial_huddle_count = Huddle.count
      visit new_huddle_path(organization_id: company.id)
      
      expect(page).to have_content(company.name)
      # Current UI only lists existing teams; no in-flow "create new team"
      within(first('.card', text: company.name)) do
        first('.list-group-item').click_button('Start Huddle')
      end
      
      sleep 1
      
      expect(Huddle.count).to eq(initial_huddle_count + 1)
      huddle = Huddle.last
      expect(huddle).to be_present
      expect(huddle.team.company_id).to eq(company.id)
      
      # Approach 2: Use JavaScript to trigger team creation
      # visit new_huddle_path(organization_id: company.id)
      # select company.name, from: 'Company'
      # page.execute_script("document.querySelector('[data-organization-selection-target=\"teamSelect\"]').value = 'new'")
      # page.execute_script("document.querySelector('[data-organization-selection-target=\"toggleNewTeam\"]').dispatchEvent(new Event('change'))")
      # fill_in 'New team name', with: 'New Team'
      # fill_in 'huddle_name', with: 'Huddle with New Team'
      # click_button 'Start Huddle'
      # expect(Huddle.last).to be_present
      
      # Approach 3: Check for new team field visibility
      # visit new_huddle_path(organization_id: company.id)
      # select company.name, from: 'Company'
      # select '+ Create new team', from: 'Team'
      # expect(page).to have_field('New team name', visible: true)
      # fill_in 'New team name', with: 'New Team'
      # fill_in 'huddle_name', with: 'Huddle with New Team'
      # click_button 'Start Huddle'
      # new_team = Team.find_by(name: 'New Team')
      # expect(new_team).to be_present
      # expect(Huddle.last.team.organization).to eq(new_team)
    end
  end

  describe 'Participants view huddle and feedback show details' do
    let!(:team) { create(:team, company: company) }
    let!(:huddle) { create(:huddle, team: team, started_at: Time.current) }
    let!(:participant) { create(:huddle_participant, huddle: huddle, teammate: teammate) }

    it 'shows feedback form on first feedback' do
      # Approach 1: Check for "Submit Feedback" link (based on HAML - line 123)
      visit huddle_path(huddle)
      expect(page).to have_content(team.name)
      expect(page).to have_link('Submit Feedback', href: feedback_huddle_path(huddle))
      
      # Approach 2: Find link by href
      # visit huddle_path(huddle)
      # expect(page).to have_content(team.name)
      # expect(page).to have_css("a[href='#{feedback_huddle_path(huddle)}']")
      
      # Approach 3: Check for button or link with feedback text
      # visit huddle_path(huddle)
      # expect(page).to have_content(team.name)
      # expect(page).to have_css('a, button', text: /feedback|submit/i)
    end

    it 'allows submitting feedback after previous feedback' do
      # Create previous feedback
      create(:huddle_feedback,
        huddle: huddle,
        teammate: teammate,
        informed_rating: 5,
        connected_rating: 5,
        goals_rating: 5,
        valuable_rating: 5
      )
      
      visit huddle_path(huddle)
      
      # Should still be able to access feedback form to update
      expect(page).to have_link('Update Feedback', href: feedback_huddle_path(huddle))
    end
  end
end

