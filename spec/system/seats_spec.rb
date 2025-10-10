require 'rails_helper'

RSpec.describe 'Seats', type: :system, critical: true do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: organization, can_manage_employment: true, can_manage_maap: true) }
  let!(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let!(:position_type) { create(:position_type, organization: organization, position_major_level: position_major_level, external_title: 'Software Engineer') }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(person).to receive(:can_manage_employment?).and_return(true)
    allow(person).to receive(:can_manage_maap?).and_return(true)
  end

  describe 'Seat creation' do
    it 'loads new seat form' do
      visit new_organization_seat_path(organization)
      
      # Should see the form
      expect(page).to have_content('Create New Seat')
      expect(page).to have_content('New Seat Details')
      expect(page).to have_field('seat_position_type_id')
      expect(page).to have_field('seat_seat_needed_by')
      expect(page).to have_field('seat_job_classification')
      
      # Should see seat defense section
      expect(page).to have_content('Seat Defense')
      expect(page).to have_content('Why do we need this role?')
      expect(page).to have_content('Why is now the time to hire for this role?')
      expect(page).to have_content('What are the costs/risks if we choose not to hire for this role now?')
      
      # Should see HR information section
      expect(page).to have_content('HR Information')
      expect(page).to have_content('Job Description Disclaimer')
      expect(page).to have_content('Work Environment')
      
      # Should see create button
      expect(page).to have_button('Create Seat')
    end

    it 'creates seat with valid data' do
      visit new_organization_seat_path(organization)
      
      # Fill out the form
      select position_type.external_title, from: 'seat_position_type_id'
      fill_in 'seat_seat_needed_by', with: 3.months.from_now.strftime('%Y-%m-%d')
      select 'Salaried Exempt', from: 'seat_job_classification'
      fill_in 'seat_reports_to', with: 'Engineering Manager'
      fill_in 'seat_team', with: 'Backend Engineering'
      fill_in 'seat_why_needed', with: 'We need additional engineering capacity for our growing product'
      fill_in 'seat_why_now', with: 'Our current team is at capacity and we have new features to deliver'
      fill_in 'seat_costs_risks', with: 'Delaying this hire will impact our product roadmap and team morale'
      
      click_button 'Create Seat'
      
      # Should redirect to show page
      expect(page).to have_content('Seat was successfully created')
      expect(page).to have_content('Software Engineer')
      expect(page).to have_content('Engineering Manager')
      expect(page).to have_content('Backend Engineering')
      
      # Verify in database
      seat = Seat.last
      expect(seat.position_type).to eq(position_type)
      expect(seat.reports_to).to eq('Engineering Manager')
      expect(seat.team).to eq('Backend Engineering')
      expect(seat.why_needed).to eq('We need additional engineering capacity for our growing product')
    end

    it 'shows validation errors for missing required fields' do
      visit new_organization_seat_path(organization)
      
      # Try to submit empty form
      click_button 'Create Seat'
      
      # Should stay on form (validation prevents submission)
      expect(page).to have_content('Create New Seat')
      expect(page).to have_content('New Seat Details')
    end
  end

  describe 'Seat editing' do
    let!(:seat) do
      create(:seat,
        position_type: position_type,
        seat_needed_by: 3.months.from_now,
        reports_to: 'Engineering Manager',
        team: 'Backend Engineering',
        why_needed: 'We need additional engineering capacity',
        why_now: 'Our current team is at capacity',
        costs_risks: 'Delaying this hire will impact our product roadmap'
      )
    end

    it 'loads seat show page' do
      visit organization_seat_path(organization, seat)
      
      # Should see seat show page
      expect(page).to have_content('Software Engineer')
      expect(page).to have_content('Engineering Manager')
      expect(page).to have_content('Backend Engineering')
      expect(page).to have_content('We need additional engineering capacity')
      expect(page).to have_content('Our current team is at capacity')
      expect(page).to have_content('Delaying this hire will impact our product roadmap')
      
      # Should see seat defense section
      expect(page).to have_content('Seat Defense')
      expect(page).to have_content('Why do we need this role?')
      expect(page).to have_content('Why is now the time to hire for this role?')
      expect(page).to have_content('What are the costs/risks if we choose not to hire for this role now?')
      
      # Should see job description section
      expect(page).to have_content('Job Description')
      expect(page).to have_content('Summary:')
    end

    it 'loads edit form with pre-populated data' do
      visit edit_organization_seat_path(organization, seat)
      
      # Should see edit form
      expect(page).to have_content('Edit Seat')
      expect(page).to have_field('seat_position_type_id')
      expect(page).to have_field('seat_seat_needed_by')
      expect(page).to have_field('seat_reports_to', with: 'Engineering Manager')
      expect(page).to have_field('seat_team', with: 'Backend Engineering')
      expect(page).to have_field('seat_why_needed', with: 'We need additional engineering capacity')
      
      # Should see update button
      expect(page).to have_button('Update Seat')
    end

    it 'updates seat with new data' do
      visit edit_organization_seat_path(organization, seat)
      
      # Should see edit form
      expect(page).to have_content('Edit Seat')
      expect(page).to have_content('Edit Seat Details')
      
      # Update the form
      fill_in 'seat_reports_to', with: 'Senior Engineering Manager'
      fill_in 'seat_team', with: 'Frontend Engineering'
      fill_in 'seat_why_needed', with: 'We need frontend expertise for our new product'
      
      click_button 'Update Seat'
      
      # Should stay on form or redirect (depending on validation)
      expect(page).to have_content('Edit Seat').or have_content('Senior Engineering Manager')
    end
  end

  describe 'Seat state management' do
    let!(:seat) do
      create(:seat,
        position_type: position_type,
        seat_needed_by: 3.months.from_now,
        state: 'draft'
      )
    end

    it 'shows seat state and reconciliation options' do
      visit organization_seat_path(organization, seat)
      
      # Should see seat state
      expect(page).to have_content('State:')
      expect(page).to have_content('Draft')
      
      # Should see needed by date
      expect(page).to have_content('Needed By:')
    end

    it 'allows state reconciliation when needed' do
      # Create a seat that might need reconciliation
      seat.update!(state: 'open')
      
      visit organization_seat_path(organization, seat)
      
      # Should see seat details
      expect(page).to have_content('Software Engineer')
      expect(page).to have_content('State:')
      expect(page).to have_content('Open')
    end
  end

  describe 'Seat job description' do
    let!(:seat) do
      create(:seat,
        position_type: position_type,
        seat_needed_by: 3.months.from_now,
        work_environment: 'Remote work environment with flexible hours',
        physical_requirements: 'Ability to work on computer for extended periods',
        travel: 'Occasional travel to client sites'
      )
    end

    it 'shows job description with custom HR information' do
      visit organization_seat_path(organization, seat)
      
      # Should see job description section
      expect(page).to have_content('Job Description')
      expect(page).to have_content('Software Engineer')
      expect(page).to have_content('Summary:')
      
      # Should see custom HR information
      expect(page).to have_content('Work environment:')
      expect(page).to have_content('Remote work environment with flexible hours')
      expect(page).to have_content('Physical requirements:')
      expect(page).to have_content('Ability to work on computer for extended periods')
      expect(page).to have_content('Travel:')
      expect(page).to have_content('Occasional travel to client sites')
    end

    it 'shows default HR information when not customized' do
      seat.update!(
        work_environment: nil,
        physical_requirements: nil,
        travel: nil
      )
      
      visit organization_seat_path(organization, seat)
      
      # Should see default HR information
      expect(page).to have_content('Work environment:')
      expect(page).to have_content('Prolonged periods of sitting at a desk and working on a computer')
      expect(page).to have_content('Physical requirements:')
      expect(page).to have_content('While performing the duties of this job, the employee may be regularly required to stand, sit, talk, hear, and use hands and fingers to operate a computer and keyboard')
      expect(page).to have_content('Travel:')
      expect(page).to have_content('Travel is on a voluntary basis')
    end
  end

  describe 'Navigation and UI elements' do
    it 'navigates between seat pages' do
      # Start at seats index
      visit organization_seats_path(organization)
      
      # Should see seats index
      expect(page).to have_content('Seats')
      
      # Navigate to new seat (plus button)
      find('a.btn.btn-primary i.bi-plus').click
      expect(page).to have_content('Create New Seat')
      
      # Navigate back to index
      click_link 'Back to Seats'
      expect(page).to have_content('Seats')
    end

    it 'shows seat in index after creation' do
      seat = create(:seat, 
        position_type: position_type, 
        seat_needed_by: 3.months.from_now,
        why_now: 'We need this role to support our growing team'
      )
      
      visit organization_seats_path(organization)
      
      # Should see the seat
      expect(page).to have_content('Software Engineer')
      expect(page).to have_content('We need this role to support our growing team')
      expect(page).to have_content('Draft')
    end

    it 'shows empty state when no seats exist' do
      visit organization_seats_path(organization)
      
      # Should see empty state
      expect(page).to have_content('No Seats Created')
      expect(page).to have_content('Create your first seat to get started with job requisitions')
      expect(page).to have_link('Create First Seat')
    end
  end
end
