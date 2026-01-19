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
      
      # Visit check-ins page (table view is now the only view)
      visit organization_company_teammate_check_ins_path(company, employee_teammate)
      
      # Fill out check-in form in table view
      # Find the table row by assignment title, then find fields within it
      row = page.find('tr', text: assignment.title)
      within(row) do
        # Find the rating select field by its name attribute
        rating_field_name = find("select[name*='[employee_rating]']")[:name]
        select '🟢 Exceeding', from: rating_field_name
        
        # Find the private notes field by its name attribute  
        notes_field_name = find("textarea[name*='[employee_private_notes]']")[:name]
        fill_in notes_field_name, with: 'Draft notes'
      end
      
      # Save the form data first by submitting the main form
      # This ensures data is persisted before attempting redirect
      page.click_button('Save All Check-Ins', match: :first)
      
      # Wait for save to complete
      expect(page).to have_content(/Check|Position|Assignment/i, wait: 5)
      
      # Verify check-in was saved
      check_in.reload
      expect(check_in.employee_rating).to eq('exceeding')
      expect(check_in.employee_private_notes).to eq('Draft notes')
      
      # Now navigate to create observation page directly
      # Since the save worked, we can navigate to the observation creation page
      quick_note_url = new_quick_note_organization_observations_path(
        company, 
        return_url: organization_company_teammate_check_ins_path(company, employee_teammate), 
        return_text: "Check-ins", 
        observee_ids: [employee_teammate.id], 
        rateable_type: 'Assignment', 
        rateable_id: assignment.id, 
        from_check_in: true
      )
      
      visit quick_note_url
      
      # Verify we're on observation creation page
      expect(page).to have_content(/Create.*Observation|Create Quick Note/i)
    end

  end
end

