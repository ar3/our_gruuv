require 'rails_helper'

RSpec.describe 'Assignment Finalization - Real Scenario Bug', type: :system do
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

  describe 'BUG: Manager cannot see assignment check-ins when position check-in is finalized' do
    # This reproduces the exact scenario from the real data:
    # - No ready position check-in
    # - One finalized position check-in (triggers employee acknowledgment view)
    # - Two ready assignment check-ins (should be visible but aren't)
    
    let!(:finalized_position_check_in) do
      employment_tenure = EmploymentTenure.find_by(teammate: employee_teammate, company: organization)
      PositionCheckIn.create!(
        teammate: employee_teammate,
        employment_tenure: employment_tenure,
        check_in_started_on: 2.weeks.ago,
        employee_rating: 2,
        employee_private_notes: 'Some things happened and I am less than confident',
        employee_completed_at: 2.weeks.ago,
        manager_rating: 3,
        manager_private_notes: 'Some private notes... moved to praising/trusting',
        manager_completed_at: 2.weeks.ago,
        manager_completed_by: manager_person,
        official_rating: 3,
        shared_notes: 'We landed on praising after chatting',
        official_check_in_completed_at: 2.weeks.ago,
        finalized_by: manager_person
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

    it 'BUG: Manager cannot see assignment check-ins when viewing finalized position check-in' do
      sign_in_and_visit(manager_person, organization, organization_person_finalization_path(organization, employee_person))
      
      # Debug output to match what you're seeing
      puts "\n===== REPRODUCING REAL BUG ====="
      puts "Current URL: #{page.current_url}"
      puts "Page title: #{page.title}"
      puts "\nPage contains 'Review finalized check-ins': #{page.has_content?('Review finalized check-ins')}"
      puts "Page contains 'Position Check-In - Finalized': #{page.has_content?('Position Check-In - Finalized')}"
      puts "Page contains 'Assignment Check-Ins': #{page.has_content?('Assignment Check-Ins')}"
      puts "Page contains 'Backend API Development': #{page.has_content?('Backend API Development')}"
      puts "Page contains 'Database Optimization': #{page.has_content?('Database Optimization')}"
      puts "Page contains 'Finalize Selected Check-Ins' button: #{page.has_button?('Finalize Selected Check-Ins')}"
      puts "\nFull page text (first 1000 chars):"
      puts page.text[0..1000]
      puts "===== END DEBUG ====="
      
      # This test SHOULD FAIL because assignments are not visible
      # The bug is that when there's a finalized position check-in,
      # the view shows employee acknowledgment mode and ignores assignments
      
      # The bug has been fixed! Assignment check-ins are now visible
      expect(page).to have_content('Assignment Check-Ins')
      expect(page).to have_content('Backend API Development')
      expect(page).to have_content('Database Optimization')
      expect(page).to have_button('Finalize Selected Check-Ins')
      
      # We can also see the finalized position check-in
      expect(page).to have_content('Position Check-In - Finalized')
    end

    it 'Employee can now see assignment check-ins in this scenario' do
      sign_in_and_visit(employee_person, organization, organization_person_finalization_path(organization, employee_person))
      
      # The bug has been fixed! Employee can now see assignment check-ins
      expect(page).to have_content('Assignment Check-Ins')
      expect(page).to have_content('Backend API Development')
    end
  end
end
