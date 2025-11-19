require 'rails_helper'

RSpec.describe 'Finalization Complex Flow - Custom Reason', type: :system do
  let(:company) { create(:organization, :company) }
  let(:manager_person) { create(:person, full_name: 'Manager') }
  let!(:manager_teammate) { CompanyTeammate.create!(person: manager_person, organization: company, can_manage_employment: true) }
  let!(:employee_person) { create(:person, full_name: 'John Doe', email: 'john@example.com') }
  let!(:employee_teammate) { CompanyTeammate.create!(person: employee_person, organization: company) }
  let!(:assignment) { create(:assignment, company: company, title: 'Test Assignment') }
  
  # Create employment tenures (required for authorization)
  let!(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let!(:position_type) { create(:position_type, organization: company, external_title: 'Engineer', position_major_level: position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let!(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let!(:manager_employment_tenure) do
    manager_teammate.update!(first_employed_at: 1.year.ago)
    create(:employment_tenure,
           teammate: manager_teammate,
           company: company,
           position: position,
           started_at: 1.year.ago,
           ended_at: nil)
  end
  let!(:employee_employment_tenure) do
    create(:employment_tenure,
           teammate: employee_teammate,
           company: company,
           position: position,
           manager: manager_person,
           started_at: 1.month.ago)
  end
  
  # Create assignment tenure
  let!(:assignment_tenure) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, started_at: 6.months.ago) }
  
  # Check-in where both sides completed
  let!(:check_in) do
    check_in = AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment)
    check_in&.update!(
      employee_rating: 'exceeding',
      employee_completed_at: Time.current,
      manager_rating: 'meeting',
      manager_completed_at: Time.current,
      manager_completed_by: manager_person
    )
    check_in
  end

  describe 'Manager can enter custom reason' do
    before do
      sign_in_as(manager_person, company)
    end

    it 'allows manager to edit the reason field' do
      visit organization_person_finalization_path(company, employee_person)
      
      reason_field = find_field('maap_snapshot_reason')
      expect(reason_field).to be_visible
      expect(reason_field.value).to eq("Check-in finalization for #{employee_person.display_name}")
      
      # Clear and enter custom reason
      reason_field.fill_in(with: 'Q4 2024 Performance Review')
      expect(reason_field.value).to eq('Q4 2024 Performance Review')
    end
  end

  describe 'Manager can submit with custom reason' do
    before do
      sign_in_as(manager_person, company)
    end

    it 'creates snapshot with custom reason' do
      visit organization_person_finalization_path(company, employee_person)
      
      # Verify check-in is ready
      expect(check_in.reload.ready_for_finalization?).to be true
      
      # Enter custom reason
      fill_in 'maap_snapshot_reason', with: 'Q4 2024 Performance Review'
      
      # Finalize the check-in
      check_box = find("input[type='checkbox'][name='assignment_check_ins[#{check_in.id}][finalize]']")
      check_box.check
      
      select '🟢 Exceeding', from: "assignment_check_ins[#{check_in.id}][official_rating]"
      fill_in "assignment_check_ins[#{check_in.id}][shared_notes]", with: 'Test notes'
      
      # Submit form using JavaScript (bypasses confirmation dialog)
      page.execute_script("document.querySelector('form[action*=\"finalization\"]').submit()")
      sleep 3 # Wait for processing
      
      # Verify snapshot was created with custom reason
      snapshot = MaapSnapshot.last
      expect(snapshot).to be_present
      expect(snapshot.reason).to eq('Q4 2024 Performance Review')
      expect(snapshot.employee).to eq(employee_person)
      expect(snapshot.created_by).to eq(manager_person)
      
      # Verify check-in was finalized
      expect(check_in.reload.official_check_in_completed_at).to be_present
    end
  end

  describe 'Custom reason appears correctly on audit page' do
    let(:custom_reason) { 'Q4 2024 Performance Review' }
    let!(:snapshot) do
      create(:maap_snapshot,
             employee: employee_person,
             created_by: manager_person,
             company: company,
             change_type: 'assignment_management',
             reason: custom_reason,
             effective_date: Date.current)
    end

    before do
      sign_in_as(manager_person, company)
    end

    it 'displays the custom reason in the audit page' do
      visit audit_organization_employee_path(company, employee_person)
      
      expect(page).to have_content(custom_reason)
      expect(page).to have_content('MAAP Change History')
    end

    it 'truncates long reasons correctly' do
      long_reason = 'A' * 100
      snapshot.update!(reason: long_reason)
      
      visit audit_organization_employee_path(company, employee_person)
      
      # The reason should be truncated to 50 characters in the table
      truncated = long_reason.truncate(50)
      expect(page).to have_content(truncated)
    end
  end

  describe 'Multiple finalizations with different reasons are distinguishable' do
    let!(:assignment2) { create(:assignment, company: company, title: 'Test Assignment 2') }
    let!(:assignment_tenure2) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment2, started_at: 3.months.ago) }
    
    let!(:check_in2) do
      check_in = AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment2)
      check_in&.update!(
        employee_rating: 'meeting',
        employee_completed_at: Time.current,
        manager_rating: 'exceeding',
        manager_completed_at: Time.current,
        manager_completed_by: manager_person
      )
      check_in
    end

    let!(:snapshot1) do
      create(:maap_snapshot,
             employee: employee_person,
             created_by: manager_person,
             company: company,
             change_type: 'assignment_management',
             reason: 'Q4 2024 Performance Review',
             effective_date: 2.days.ago)
    end

    let!(:snapshot2) do
      create(:maap_snapshot,
             employee: employee_person,
             created_by: manager_person,
             company: company,
             change_type: 'assignment_management',
             reason: 'Annual Check-in',
             effective_date: 1.day.ago)
    end

    before do
      sign_in_as(manager_person, company)
    end

    it 'shows both reasons distinctly on audit page' do
      visit audit_organization_employee_path(company, employee_person)
      
      expect(page).to have_content('Q4 2024 Performance Review')
      expect(page).to have_content('Annual Check-in')
      
      # Verify both snapshots appear
      expect(page).to have_content(snapshot1.change_type.humanize, count: 2)
    end
  end
end

