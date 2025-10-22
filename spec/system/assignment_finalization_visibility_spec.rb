require 'rails_helper'

RSpec.describe 'Assignment Finalization Visibility', type: :system do
  let(:organization) { create(:organization) }
  let(:manager_person) { create(:person, first_name: 'Manager', last_name: 'Smith') }
  let(:employee_person) { create(:person, first_name: 'Employee', last_name: 'Jones') }
  let(:manager_teammate) { create(:teammate, person: manager_person, organization: organization) }
  let(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }
  let(:position_major_level) { create(:position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:position_type) { create(:position_type, organization: organization, position_major_level: position_major_level) }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let(:assignment1) { create(:assignment, company: organization, title: 'Backend API Development') }
  let(:assignment2) { create(:assignment, company: organization, title: 'Database Optimization') }
  
  before do
    # Set up employment relationship
    create(:employment_tenure, 
           teammate: employee_teammate, 
           company: organization,
           position: position, 
           manager: manager_person,
           started_at: 1.month.ago)
    
    # Set up assignment tenures
    create(:assignment_tenure,
           teammate: employee_teammate,
           assignment: assignment1,
           anticipated_energy_percentage: 60,
           started_at: 1.month.ago)
    
    create(:assignment_tenure,
           teammate: employee_teammate,
           assignment: assignment2,
           anticipated_energy_percentage: 40,
           started_at: 1.month.ago)
    
    # Set up authentication
    manager_person.update!(current_organization: organization)
    employee_person.update!(current_organization: organization)
  end

  describe 'Manager View - Assignment Check-ins WITHOUT Position Check-in' do
    let!(:assignment_check_in_1) do
      AssignmentCheckIn.create!(
        teammate: employee_teammate,
        assignment: assignment1,
        check_in_started_on: Date.current,
        actual_energy_percentage: 65,
        employee_rating: 'meeting',
        employee_private_notes: 'Going well on backend',
        employee_completed_at: Time.current,
        manager_rating: 'exceeding',
        manager_private_notes: 'Great work on API',
        manager_completed_at: Time.current,
        manager_completed_by: manager_person
      )
    end

    let!(:assignment_check_in_2) do
      AssignmentCheckIn.create!(
        teammate: employee_teammate,
        assignment: assignment2,
        check_in_started_on: Date.current,
        actual_energy_percentage: 45,
        employee_rating: 'working_to_meet',
        employee_private_notes: 'Struggling with optimization',
        employee_completed_at: Time.current,
        manager_rating: 'meeting',
        manager_private_notes: 'Making progress',
        manager_completed_at: Time.current,
        manager_completed_by: manager_person
      )
    end

    it 'displays both assignment check-ins on finalization page for manager' do
      sign_in_and_visit(manager_person, organization, organization_person_finalization_path(organization, employee_person))
      
      # Debug output
      puts "\n===== MANAGER VIEW WITHOUT POSITION CHECK-IN ====="
      puts "Current URL: #{page.current_url}"
      puts "Page title: #{page.title}"
      puts "\nPage contains 'Assignment Check-Ins': #{page.has_content?('Assignment Check-Ins')}"
      puts "Page contains 'Backend API Development': #{page.has_content?('Backend API Development')}"
      puts "Page contains 'Database Optimization': #{page.has_content?('Database Optimization')}"
      puts "Page contains 'Finalize Selected Check-Ins' button: #{page.has_button?('Finalize Selected Check-Ins')}"
      puts "\nFull page text (first 500 chars):"
      puts page.text[0..500]
      puts "===== END DEBUG ====="
      
      # Assertions
      expect(page).to have_content('Finalize Check-Ins for Employee Jones')
      
      # Check for assignment section header
      expect(page).to have_content('Assignment Check-Ins')
      
      # Check for both assignments
      expect(page).to have_content('Backend API Development')
      expect(page).to have_content('Database Optimization')
      
      # Check for form fields
      expect(page).to have_select("assignment_check_ins[#{assignment_check_in_1.id}][official_rating]")
      expect(page).to have_field("assignment_check_ins[#{assignment_check_in_1.id}][shared_notes]")
      expect(page).to have_select("assignment_check_ins[#{assignment_check_in_2.id}][official_rating]")
      expect(page).to have_field("assignment_check_ins[#{assignment_check_in_2.id}][shared_notes]")
      
      # Check for finalize checkbox
      expect(page).to have_field('finalize_assignments')
      
      # Check for submit button
      expect(page).to have_button('Finalize Selected Check-Ins')
    end
  end

  describe 'Manager View - Assignment Check-ins WITH Position Check-in' do
    let!(:position_check_in) do
      employment_tenure = EmploymentTenure.find_by(teammate: employee_teammate, company: organization)
      PositionCheckIn.create!(
        teammate: employee_teammate,
        employment_tenure: employment_tenure,
        check_in_started_on: Date.current,
        employee_rating: 2,
        employee_private_notes: 'Doing well overall',
        employee_completed_at: 1.hour.ago,
        manager_rating: 3,
        manager_private_notes: 'Strong performer',
        manager_completed_at: 30.minutes.ago,
        manager_completed_by: manager_person
      )
    end

    let!(:assignment_check_in_1) do
      AssignmentCheckIn.create!(
        teammate: employee_teammate,
        assignment: assignment1,
        check_in_started_on: Date.current,
        actual_energy_percentage: 65,
        employee_rating: 'meeting',
        employee_private_notes: 'Going well on backend',
        employee_completed_at: Time.current,
        manager_rating: 'exceeding',
        manager_private_notes: 'Great work on API',
        manager_completed_at: Time.current,
        manager_completed_by: manager_person
      )
    end

    let!(:assignment_check_in_2) do
      AssignmentCheckIn.create!(
        teammate: employee_teammate,
        assignment: assignment2,
        check_in_started_on: Date.current,
        actual_energy_percentage: 45,
        employee_rating: 'working_to_meet',
        employee_private_notes: 'Struggling with optimization',
        employee_completed_at: Time.current,
        manager_rating: 'meeting',
        manager_private_notes: 'Making progress',
        manager_completed_at: Time.current,
        manager_completed_by: manager_person
      )
    end

    it 'displays position AND assignment check-ins on finalization page for manager' do
      sign_in_and_visit(manager_person, organization, organization_person_finalization_path(organization, employee_person))
      
      # Debug output
      puts "\n===== MANAGER VIEW WITH POSITION CHECK-IN ====="
      puts "Current URL: #{page.current_url}"
      puts "Page title: #{page.title}"
      puts "\nPage contains 'Position Check-In': #{page.has_content?('Position Check-In')}"
      puts "Page contains 'Assignment Check-Ins': #{page.has_content?('Assignment Check-Ins')}"
      puts "Page contains 'Backend API Development': #{page.has_content?('Backend API Development')}"
      puts "Page contains 'Database Optimization': #{page.has_content?('Database Optimization')}"
      puts "Page contains 'Finalize Selected Check-Ins' button: #{page.has_button?('Finalize Selected Check-Ins')}"
      puts "\nFull page text (first 500 chars):"
      puts page.text[0..500]
      puts "===== END DEBUG ====="
      
      # Assertions - Position
      expect(page).to have_content('Position Check-In')
      expect(page).to have_field('finalize_position')
      
      # Assertions - Assignments
      expect(page).to have_content('Assignment Check-Ins')
      expect(page).to have_content('Backend API Development')
      expect(page).to have_content('Database Optimization')
      
      # Check for form fields
      expect(page).to have_select("assignment_check_ins[#{assignment_check_in_1.id}][official_rating]")
      expect(page).to have_select("assignment_check_ins[#{assignment_check_in_2.id}][official_rating]")
      expect(page).to have_field('finalize_assignments')
      
      # Check for submit button
      expect(page).to have_button('Finalize Selected Check-Ins')
    end
  end

  describe 'Employee View - Assignment Check-ins WITHOUT Position Check-in' do
    let!(:assignment_check_in_1) do
      AssignmentCheckIn.create!(
        teammate: employee_teammate,
        assignment: assignment1,
        check_in_started_on: Date.current,
        actual_energy_percentage: 65,
        employee_rating: 'meeting',
        employee_private_notes: 'Going well on backend',
        employee_completed_at: Time.current,
        manager_rating: 'exceeding',
        manager_private_notes: 'Great work on API',
        manager_completed_at: Time.current,
        manager_completed_by: manager_person
      )
    end

    it 'shows read-only view for employee when assignments are ready for finalization' do
      sign_in_and_visit(employee_person, organization, organization_person_finalization_path(organization, employee_person))
      
      # Debug output
      puts "\n===== EMPLOYEE VIEW WITHOUT POSITION CHECK-IN ====="
      puts "Current URL: #{page.current_url}"
      puts "Page title: #{page.title}"
      puts "\nPage contains 'Backend API Development': #{page.has_content?('Backend API Development')}"
      puts "Page contains 'Your manager will review': #{page.has_content?('Your manager will review')}"
      puts "Page contains 'Finalize Selected Check-Ins' button: #{page.has_button?('Finalize Selected Check-Ins')}"
      puts "\nFull page text (first 500 chars):"
      puts page.text[0..500]
      puts "===== END DEBUG ====="
      
      # Employee should see their assignment but in read-only mode
      expect(page).to have_content('Backend API Development')
      
      # Employee should NOT see finalization button
      expect(page).not_to have_button('Finalize Selected Check-Ins')
      
      # Employee should see a message about manager review
      expect(page).to have_content('Your manager will review')
    end
  end

  describe 'Employee View - Assignment Check-ins WITH Position Check-in' do
    let!(:position_check_in) do
      employment_tenure = EmploymentTenure.find_by(teammate: employee_teammate, company: organization)
      PositionCheckIn.create!(
        teammate: employee_teammate,
        employment_tenure: employment_tenure,
        check_in_started_on: Date.current,
        employee_rating: 2,
        employee_private_notes: 'Doing well overall',
        employee_completed_at: 1.hour.ago,
        manager_rating: 3,
        manager_private_notes: 'Strong performer',
        manager_completed_at: 30.minutes.ago,
        manager_completed_by: manager_person
      )
    end

    let!(:assignment_check_in_1) do
      AssignmentCheckIn.create!(
        teammate: employee_teammate,
        assignment: assignment1,
        check_in_started_on: Date.current,
        actual_energy_percentage: 65,
        employee_rating: 'meeting',
        employee_private_notes: 'Going well on backend',
        employee_completed_at: Time.current,
        manager_rating: 'exceeding',
        manager_private_notes: 'Great work on API',
        manager_completed_at: Time.current,
        manager_completed_by: manager_person
      )
    end

    it 'shows read-only view for employee with both position and assignments' do
      sign_in_and_visit(employee_person, organization, organization_person_finalization_path(organization, employee_person))
      
      # Debug output
      puts "\n===== EMPLOYEE VIEW WITH POSITION CHECK-IN ====="
      puts "Current URL: #{page.current_url}"
      puts "Page title: #{page.title}"
      puts "\nPage contains 'Position Check-In': #{page.has_content?('Position Check-In')}"
      puts "Page contains 'Backend API Development': #{page.has_content?('Backend API Development')}"
      puts "Page contains 'Your manager will review': #{page.has_content?('Your manager will review')}"
      puts "Page contains 'Finalize Selected Check-Ins' button: #{page.has_button?('Finalize Selected Check-Ins')}"
      puts "\nFull page text (first 500 chars):"
      puts page.text[0..500]
      puts "===== END DEBUG ====="
      
      # Employee should see position check-in
      expect(page).to have_content('Position Check-In')
      
      # Employee should see their assignment
      expect(page).to have_content('Backend API Development')
      
      # Employee should NOT see finalization button
      expect(page).not_to have_button('Finalize Selected Check-Ins')
      
      # Employee should see a message about manager review
      expect(page).to have_content('Your manager will review')
    end
  end
end

