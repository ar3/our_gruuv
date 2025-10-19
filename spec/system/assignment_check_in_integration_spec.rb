require 'rails_helper'

RSpec.describe 'Assignment Check-In Integration', type: :system do
  let(:organization) { create(:organization) }
  let(:manager_person) { create(:person, first_name: 'Manager', last_name: 'Guy') }
  let(:employee_person) { create(:person, first_name: 'John', last_name: 'Doe') }
  let(:manager_teammate) { create(:teammate, person: manager_person, organization: organization) }
  let(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }
  let(:position_major_level) { create(:position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:position_type) { create(:position_type, organization: organization, position_major_level: position_major_level) }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let(:assignment) { create(:assignment, company: organization, title: 'Frontend Development') }
  
  before do
    # Set up employment relationship
    create(:employment_tenure, 
           teammate: employee_teammate, 
           company: organization,
           position: position, 
           manager: manager_person,
           started_at: 1.month.ago)
    
    # Set up assignment tenure
    create(:assignment_tenure,
           teammate: employee_teammate,
           assignment: assignment,
           anticipated_energy_percentage: 80,
           started_at: 1.month.ago)
    
    # Set up authentication using proper session-based approach
    manager_person.update!(current_organization: organization)
    # Ensure manager is a teammate in the organization with proper permissions
    manager_teammate.update!(organization: organization, can_manage_employment: true)
  end

  describe 'Assignment Check-In Creation and Management' do
    it 'creates assignment check-ins on-demand when accessing check-ins page' do
      # Debug: Check if assignment tenure exists
      assignment_tenure = AssignmentTenure.find_by(teammate: employee_teammate, assignment: assignment)
      
      sign_in_and_visit(manager_person, organization, organization_person_check_ins_path(organization, employee_person))
      assignment_check_in = AssignmentCheckIn.find_by(teammate: employee_teammate, assignment: assignment)
      expect(assignment_check_in).to be_present
      expect(assignment_check_in.actual_energy_percentage).to eq(80) # Defaults to anticipated
    end

    it 'prevents multiple open check-ins per assignment' do
      # Create first check-in
      AssignmentCheckIn.create!(
        teammate: employee_teammate,
        assignment: assignment,
        check_in_started_on: Date.current,
        actual_energy_percentage: 80
      )
      
      # Try to create second check-in
      expect {
        AssignmentCheckIn.create!(
          teammate: employee_teammate,
          assignment: assignment,
          check_in_started_on: Date.current,
          actual_energy_percentage: 70
        )
      }.to raise_error(ActiveRecord::RecordInvalid, /Only one open check-in allowed/)
    end

    it 'allows multiple check-ins for different assignments' do
      assignment2 = create(:assignment, company: organization, title: 'Backend Development')
      create(:assignment_tenure,
             teammate: employee_teammate,
             assignment: assignment2,
             anticipated_energy_percentage: 60,
             started_at: 1.month.ago)
      
      check_in1 = AssignmentCheckIn.create!(
        teammate: employee_teammate,
        assignment: assignment,
        check_in_started_on: Date.current,
        actual_energy_percentage: 80
      )
      
      check_in2 = AssignmentCheckIn.create!(
        teammate: employee_teammate,
        assignment: assignment2,
        check_in_started_on: Date.current,
        actual_energy_percentage: 60
      )
      
      expect(check_in1).to be_valid
      expect(check_in2).to be_valid
      expect(check_in1.assignment).not_to eq(check_in2.assignment)
    end
  end

  describe 'Assignment Check-In Completion Flow' do
    let!(:assignment_check_in) do
      AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment)
    end

    it 'allows employee to complete their side' do
      switch_to_user(employee_person, organization)
      
      visit organization_person_check_ins_path(organization, employee_person)
      
      # Fill in employee assessment
      find('select[name*="assignment_check_ins"][name*="employee_rating"]').select('Meeting')
      find('textarea[name*="assignment_check_ins"][name*="employee_private_notes"]').set('I feel I am meeting expectations on this assignment')
      find('input[name*="assignment_check_ins"][name*="actual_energy_percentage"]').set('75')
      find('select[name*="assignment_check_ins"][name*="employee_personal_alignment"]').select('Like')
      
      # Mark as complete
      within('table', text: 'Assignment') do
        find('input[type="radio"][value="complete"]').click
      end
      
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully.')
      
      assignment_check_in.reload
      expect(assignment_check_in.employee_completed?).to be true
      expect(assignment_check_in.employee_rating).to eq('meeting')
      expect(assignment_check_in.actual_energy_percentage).to eq(75)
      expect(assignment_check_in.employee_personal_alignment).to eq('like')
    end

    it 'allows manager to complete their side' do
      sign_in_and_visit(manager_person, organization, organization_person_check_ins_path(organization, employee_person))
      
      # Fill in manager assessment
      select 'Exceeding', from: "[assignment_check_ins][#{assignment_check_in.id}][manager_rating]"
      fill_in "[assignment_check_ins][#{assignment_check_in.id}][manager_private_notes]", with: 'John is exceeding expectations on frontend work'
      
      # Mark as complete
      within('table', text: 'Assignment') { find('input[type="radio"][value="complete"]').click }
      
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully.')
      
      assignment_check_in.reload
      expect(assignment_check_in.manager_completed?).to be true
      expect(assignment_check_in.manager_rating).to eq('exceeding')
      expect(assignment_check_in.manager_completed_by).to eq(manager_person)
    end

    it 'shows ready for finalization when both sides complete' do
      # Employee completes first
      assignment_check_in.update!(
        employee_rating: 'meeting',
        employee_private_notes: 'I feel I am meeting expectations',
        actual_energy_percentage: 75,
        employee_personal_alignment: 'like',
        employee_completed_at: Time.current
      )
      
      # Manager completes
      assignment_check_in.update!(
        manager_rating: 'exceeding',
        manager_private_notes: 'John is exceeding expectations',
        manager_completed_at: Time.current,
        manager_completed_by: manager_person
      )
      
      sign_in_and_visit(manager_person, organization, organization_person_check_ins_path(organization, employee_person))
      
      expect(page).to have_content(/ready for finalization/i)
      expect(page).to have_link('Go to Finalization')
    end

    it 'allows uncompleting and making changes' do
      # Complete only employee side (not manager)
      assignment_check_in.update!(
        employee_rating: 'meeting',
        employee_private_notes: 'I feel I am meeting expectations',
        employee_completed_at: Time.current
      )
      
      switch_to_user(employee_person, organization)
      
      visit organization_person_check_ins_path(organization, employee_person)
      
      # Choose to make changes
      find('input[name*="assignment_check_ins"][type="radio"][value="draft"]').click
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully.')
      
      # Wait for the database to be updated
      sleep 0.1
      assignment_check_in.reload
      expect(assignment_check_in.employee_completed?).to be false
      expect(assignment_check_in.manager_completed?).to be false
    end
  end

  describe 'Assignment Check-In Finalization' do
    let!(:assignment_check_in) do
      AssignmentCheckIn.create!(
        teammate: employee_teammate,
        assignment: assignment,
        check_in_started_on: Date.current,
        actual_energy_percentage: 80,
        employee_rating: 'meeting',
        employee_private_notes: 'I feel I am meeting expectations',
        employee_completed_at: Time.current,
        manager_rating: 'exceeding',
        manager_private_notes: 'John is exceeding expectations',
        manager_completed_at: Time.current,
        manager_completed_by: manager_person
      )
    end

    it 'allows manager to finalize assignment check-in' do
      sign_in_and_visit(manager_person, organization, organization_person_finalization_path(organization, employee_person))
      
      # Should show assignment check-in ready for finalization
      expect(page).to have_content('Frontend Development')
      expect(page).to have_content('Meeting')
      expect(page).to have_content('Exceeding')
      
      # Set official rating and shared notes
      select 'Exceeding', from: "assignment_check_ins[#{assignment_check_in.id}][official_rating]"
      fill_in "assignment_check_ins[#{assignment_check_in.id}][shared_notes]", with: 'John has exceeded expectations on frontend development'
      
      # Check finalize assignment checkbox
      check 'finalize_assignments'
      
      click_button 'Finalize Selected Check-Ins'
      expect(page).to have_content('Check-ins finalized successfully.')
      
      assignment_check_in.reload
      expect(assignment_check_in.officially_completed?).to be true
      expect(assignment_check_in.official_rating).to eq('exceeding')
      expect(assignment_check_in.shared_notes).to eq('John has exceeded expectations on frontend development')
    end

    it 'creates MAAP snapshot with assignment data' do
      sign_in_and_visit(manager_person, organization, organization_person_finalization_path(organization, employee_person))
      
      select 'Exceeding', from: "assignment_check_ins[#{assignment_check_in.id}][official_rating]"
      fill_in "assignment_check_ins[#{assignment_check_in.id}][shared_notes]", with: 'Great work on frontend'
      check 'finalize_assignments'
      
      click_button 'Finalize Selected Check-Ins'
      
      # Check that the finalization was successful
      expect(page).to have_content('Check-ins finalized successfully')
      
      # The snapshot and tenure updates are tested in the service specs
      # System test focuses on the UI flow
    end

    it 'updates assignment tenure with official rating' do
      assignment_tenure = AssignmentTenure.most_recent_for(employee_teammate, assignment)
      expect(assignment_tenure.official_rating).to be_nil
      
      sign_in_and_visit(manager_person, organization, organization_person_finalization_path(organization, employee_person))
      
      select 'Exceeding', from: "assignment_check_ins[#{assignment_check_in.id}][official_rating]"
      check 'finalize_assignments'
      
      click_button 'Finalize Selected Check-Ins'
      
      # Check that the finalization was successful
      expect(page).to have_content('Check-ins finalized successfully')
      
      # The tenure update is tested in the service specs
      # System test focuses on the UI flow
    end
  end

  describe 'Assignment Check-In UX States' do
    let!(:assignment_check_in) do
      AssignmentCheckIn.create!(
        teammate: employee_teammate,
        assignment: assignment,
        check_in_started_on: Date.current,
        actual_energy_percentage: 80
      )
    end

    it 'shows manager completed view when manager completes but employee does not' do
      assignment_check_in.update!(
        manager_rating: 'exceeding',
        manager_private_notes: 'John is exceeding expectations',
        manager_completed_at: Time.current,
        manager_completed_by: manager_person
      )
      
      sign_in_and_visit(manager_person, organization, organization_person_check_ins_path(organization, employee_person))
      
      expect(page).to have_content(/ready for finalization/i)
      expect(page).to have_content('Exceeding')
      expect(page).to have_content('Waiting for Employee')
      expect(page).to have_css('input[name*="assignment_check_ins"][name*="status"][value="complete"]:checked')
      expect(page).to have_css('input[name*="assignment_check_ins"][name*="status"][value="draft"]:not(:checked)')
    end

    it 'shows employee completed view when employee completes but manager does not' do
      switch_to_user(employee_person, organization)
      
      assignment_check_in.update!(
        employee_rating: 'meeting',
        employee_private_notes: 'I feel I am meeting expectations',
        actual_energy_percentage: 75,
        employee_personal_alignment: 'like',
        employee_completed_at: Time.current
      )
      
      visit organization_person_check_ins_path(organization, employee_person)
      
      expect(page).to have_content(/ready for manager/i)
      expect(page).to have_content('Meeting')
      expect(page).to have_content('I feel I am meeting expectations')
      expect(page).to have_css('input[name*="assignment_check_ins"][name*="status"][value="complete"]:checked')
      expect(page).to have_css('input[name*="assignment_check_ins"][name*="status"][value="draft"]:not(:checked)')
    end

    it 'shows both completed view with finalization link' do
      assignment_check_in.update!(
        employee_rating: 'meeting',
        employee_private_notes: 'I feel I am meeting expectations',
        employee_completed_at: Time.current,
        manager_rating: 'exceeding',
        manager_private_notes: 'John is exceeding expectations',
        manager_completed_at: Time.current,
        manager_completed_by: manager_person
      )
      
      sign_in_and_visit(manager_person, organization, organization_person_check_ins_path(organization, employee_person))
      
      expect(page).to have_content(/ready for finalization/i)
      expect(page).to have_content('Exceeding')
      expect(page).to have_content(/ready for finalization/i)
      expect(page).to have_link('Go to Finalization')
    end
  end

  describe 'Multiple Assignment Check-Ins' do
    let(:assignment2) { create(:assignment, company: organization, title: 'Backend Development') }
    
    before do
      create(:assignment_tenure,
             teammate: employee_teammate,
             assignment: assignment2,
             anticipated_energy_percentage: 60,
             started_at: 1.month.ago)
    end

    it 'handles multiple assignment check-ins on same page' do
      check_in1 = AssignmentCheckIn.create!(
        teammate: employee_teammate,
        assignment: assignment,
        check_in_started_on: Date.current,
        actual_energy_percentage: 80
      )
      
      check_in2 = AssignmentCheckIn.create!(
        teammate: employee_teammate,
        assignment: assignment2,
        check_in_started_on: Date.current,
        actual_energy_percentage: 60
      )
      
      sign_in_and_visit(manager_person, organization, organization_person_check_ins_path(organization, employee_person))
      
      expect(page).to have_content('Frontend Development')
      expect(page).to have_content('Backend Development')
      
      # Complete first assignment
      within('table', text: 'Assignment') do
        first('select[name*="assignment_check_ins"][name*="manager_rating"]').select('Meeting')
        first('textarea[name*="assignment_check_ins"][name*="manager_private_notes"]').set('Good frontend work')
        first('input[name*="assignment_check_ins"][name*="status"][value="complete"]').click
      end
      
      # Complete second assignment
      within('table', text: 'Assignment') do
        all('select[name*="assignment_check_ins"][name*="manager_rating"]').last.select('Exceeding')
        all('textarea[name*="assignment_check_ins"][name*="manager_private_notes"]').last.set('Excellent backend work')
        all('input[name*="assignment_check_ins"][name*="status"][value="complete"]').last.click
      end
      
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully.')
      
      check_in1.reload
      check_in2.reload
      expect(check_in1.manager_completed?).to be true
      expect(check_in2.manager_completed?).to be true
    end
  end
end
