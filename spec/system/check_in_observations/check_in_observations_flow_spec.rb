require 'rails_helper'

RSpec.describe 'Check-in Observations Flow', type: :system do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person, full_name: 'Manager') }
  let!(:teammate) { CompanyTeammate.create!(person: person, organization: company, can_manage_employment: true) }
  let!(:employee_person) { create(:person, full_name: 'John Doe', email: 'john@example.com') }
  let!(:employee_teammate) { CompanyTeammate.create!(person: employee_person, organization: company) }
  let!(:assignment) { create(:assignment, company: company, title: 'Assignment 1') }
  let!(:aspiration) { create(:aspiration, company: company, name: 'Aspiration 1') }
  let!(:assignment_tenure) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, started_at: 2.months.ago) }
  let!(:check_in) { AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment) }
  let!(:aspiration_check_in) { AspirationCheckIn.find_or_create_open_for(employee_teammate, aspiration) }

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
      # Find the table row by assignment title (now in a submit button)
      # Look for the row containing a button with the assignment title
      row = page.all('tr').find { |tr| tr.has_button?(assignment.title) || tr.text.include?(assignment.title) }
      within(row) do
        # Find the rating select field by its name attribute
        rating_field_name = find("select[name*='[employee_rating]']")[:name]
        select '🟢 Exceeding', from: rating_field_name
        
        # Find the private notes field by its name attribute  
        notes_field_name = find("textarea[name*='[employee_private_notes]']")[:name]
        fill_in notes_field_name, with: 'Draft notes'
      end
      
      # Click "Add Win / Challenge" button - this should save and redirect in one action
      # Find the row again to ensure we're in the right context
      row = page.all('tr').find { |tr| tr.has_button?(assignment.title) || tr.text.include?(assignment.title) }
      within(row) do
        # Find the "Add Win / Challenge" button by its name or text
        click_button 'Add Win / Challenge', match: :first
      end
      
      # Wait for redirect to observation creation page
      expect(page).to have_current_path(/new_quick_note/, wait: 10)
      
      # Verify check-in was saved before redirect
      check_in.reload
      expect(check_in.employee_rating).to eq('exceeding')
      expect(check_in.employee_private_notes).to eq('Draft notes')
      
      # Verify we're on observation creation page
      expect(page).to have_content(/Create.*Observation|Create Quick Note/i)
    end

    it 'shows ...or add a win/challenge now under early check-in when crystal clear, and saves like Add Win / Challenge' do
      create(:assignment_check_in, :finalized,
             teammate: employee_teammate,
             assignment: assignment,
             official_check_in_completed_at: 5.days.ago,
             check_in_started_on: 20.days.ago)

      check_in.reload
      expect(check_in.open?).to be true
      expect(check_in.manager_completed?).to be false

      switch_to_user(employee_person, company)
      visit organization_company_teammate_check_ins_path(company, employee_teammate)

      row = page.all('tr').find { |tr| tr.has_button?(assignment.title) || tr.text.include?(assignment.title) }
      within(row) do
        expect(page).to have_text('I want to check-in early')
        expect(page).to have_text('...or add a')
        expect(page).to have_button('win/challenge')

        click_link 'I want to check-in early'
        rating_field_name = find("select[name*='[employee_rating]']", visible: :all)[:name]
        select '🟢 Exceeding', from: rating_field_name
        notes_field_name = find("textarea[name*='[employee_private_notes]']", visible: :all)[:name]
        fill_in notes_field_name, with: 'Crystal clear CTA notes'

        all(:css, "[name*='save_and_add_quick_note_assignment_#{assignment.id}']", visible: :all).first.click
      end

      expect(page).to have_current_path(/new_quick_note/, wait: 10)

      check_in.reload
      expect(check_in.employee_rating).to eq('exceeding')
      expect(check_in.employee_private_notes).to eq('Crystal clear CTA notes')
      expect(page).to have_content(/Create.*Observation|Create Quick Note/i)
    end

    it 'shows the same win/challenge CTA for aspiration rows when crystal clear' do
      create(:aspiration_check_in, :finalized,
             teammate: employee_teammate,
             aspiration: aspiration,
             official_check_in_completed_at: 4.days.ago,
             check_in_started_on: 15.days.ago)

      aspiration_check_in.reload
      expect(aspiration_check_in.open?).to be true
      expect(aspiration_check_in.manager_completed?).to be false

      switch_to_user(employee_person, company)
      visit organization_company_teammate_check_ins_path(company, employee_teammate)

      row = page.all('tr').find { |tr| tr.has_button?(aspiration.name) }
      within(row) do
        expect(page).to have_text('I want to check-in early')
        expect(page).to have_text('...or add a')
        expect(page).to have_button('win/challenge')

        click_link 'I want to check-in early'
        rating_field_name = find("select[name*='[employee_rating]']", visible: :all)[:name]
        select '🟢 Exceeding', from: rating_field_name
        notes_field_name = find("textarea[name*='[employee_private_notes]']", visible: :all)[:name]
        fill_in notes_field_name, with: 'Aspiration crystal CTA notes'

        all(:css, "[name*='save_and_add_quick_note_aspiration_#{aspiration.id}']", visible: :all).first.click
      end

      expect(page).to have_current_path(/new_quick_note/, wait: 10)

      aspiration_check_in.reload
      expect(aspiration_check_in.employee_rating).to eq('exceeding')
      expect(aspiration_check_in.employee_private_notes).to eq('Aspiration crystal CTA notes')
    end

  end

end

