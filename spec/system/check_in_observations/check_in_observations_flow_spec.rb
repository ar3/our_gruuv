require 'rails_helper'

RSpec.describe 'Check-in Observations Flow', type: :system do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person, full_name: 'Manager') }
  let!(:teammate) { CompanyTeammate.create!(person: person, organization: company, can_manage_employment: true) }
  let!(:employee_person) { create(:person, full_name: 'John Doe', email: 'john@example.com') }
  let!(:employee_teammate) { CompanyTeammate.create!(person: employee_person, organization: company) }
  let!(:assignment) { create(:assignment, company: company, title: 'Assignment 1') }
  let!(:aspiration) { create(:aspiration, organization: company, name: 'Aspiration 1') }
  let!(:assignment_tenure) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, started_at: 2.months.ago) }
  let!(:check_in) { AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment) }

  before do
    sign_in_as(person, company)
  end

  describe 'Observations showing on check-ins' do

  end

  describe 'Creating new observation from check-in' do
    it 'saves check-in form before navigating to create observation page' do
      # Ensure check-in is in open state (should be by default)
      check_in.reload
      expect(check_in.open?).to be true
      expect(check_in.viewer_display_mode(:employee)).to eq(:show_open_fields)
      
      # Sign in as employee to fill in employee fields
      switch_to_user(employee_person, company)
      
      # Try card view instead of table view (approach 2)
      visit organization_company_teammate_check_ins_path(company, employee_teammate, view: 'card')
      
      # Fill out check-in form
      # Card view uses assignment_check_in_form which has Employee Assessment section
      # Find the card by assignment title, then find fields within it (approach 4)
      card = page.find('.card', text: assignment.title)
      within(card) do
        # Select by display text (includes emoji): "🟢 Exceeding"
        select '🟢 Exceeding', from: 'Rating'
        fill_in 'Private Notes', with: 'Draft notes'
      end
      
      # Click "Add Win / Challenge" - this should save the form and redirect
      within(card) do
        # The link is now a button that saves and redirects
        click_button 'Add Win / Challenge', match: :first
      end
      
      # Wait for the save and redirect to complete
      # The page should redirect to the new_quick_note page
      expect(page).to have_current_path(/new_quick_note/, wait: 5)
      
      # Verify check-in was saved before redirect
      check_in.reload
      expect(check_in.employee_rating).to eq('exceeding')
      expect(check_in.employee_private_notes).to eq('Draft notes')
      
      # Verify we're on observation creation page
      expect(page).to have_content('Create Observation')
    end

  end
end

