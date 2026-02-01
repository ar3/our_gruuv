require 'rails_helper'

RSpec.describe 'Finalization Simple Flow - Default Reason', type: :system do
  let(:company) { create(:organization, :company) }
  let(:manager_person) { create(:person, full_name: 'Manager') }
  let!(:manager_teammate) { CompanyTeammate.create!(person: manager_person, organization: company, can_manage_employment: true) }
  let!(:employee_person) { create(:person, full_name: 'John Doe', email: 'john@example.com') }
  let!(:employee_teammate) { CompanyTeammate.create!(person: employee_person, organization: company) }
  let!(:assignment) { create(:assignment, company: company, title: 'Test Assignment') }
  
  # Create employment tenures (required for authorization)
  let!(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let!(:title) { create(:title, company: company, external_title: 'Engineer', position_major_level: position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let!(:position) { create(:position, title: title, position_level: position_level) }
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
      manager_completed_by_teammate: manager_teammate
    )
    check_in
  end

  describe 'Manager can see reason field' do
    before do
      sign_in_as(manager_person, company)
    end

    it 'displays the reason field with default value' do
      visit organization_company_teammate_finalization_path(company, employee_teammate)
      
      expect(page).to have_field('maap_snapshot_reason', with: "Check-in finalization for #{employee_person.display_name}")
      expect(page).to have_content('Reason (optional)')
    end
  end

  describe 'Manager can submit with default reason' do
    before do
      sign_in_as(manager_person, company)
    end

    it 'creates snapshot with default reason when no custom reason entered' do
      visit organization_company_teammate_finalization_path(company, employee_teammate)
      
      # Verify check-in is ready
      expect(check_in.reload.ready_for_finalization?).to be true
      
      # Finalize the check-in without changing the reason field
      check_box = find("input[type='checkbox'][name='assignment_check_ins[#{check_in.id}][finalize]']")
      check_box.check
      
      select '🟢 Exceeding', from: "assignment_check_ins[#{check_in.id}][official_rating]"
      fill_in "assignment_check_ins[#{check_in.id}][shared_notes]", with: 'Test notes'
      
      # Submit form using JavaScript (bypasses confirmation dialog)
      page.execute_script("document.querySelector('form[action*=\"finalization\"]').submit()")
      sleep 3 # Wait for processing
      
      # Verify snapshot was created with default reason
      snapshot = MaapSnapshot.last
      expect(snapshot).to be_present
      expect(snapshot.reason).to eq("Check-in finalization for #{employee_person.display_name}")
      expect(snapshot.employee_company_teammate).to eq(employee_teammate)
      expect(snapshot.creator_company_teammate).to eq(manager_teammate)
      
      # Verify check-in was finalized
      expect(check_in.reload.official_check_in_completed_at).to be_present
    end
  end

  describe 'Reason appears on audit page' do
    let!(:snapshot) do
      create(:maap_snapshot,
             employee_company_teammate: employee_teammate,
             creator_company_teammate: manager_teammate,
             company: company,
             change_type: 'assignment_management',
             reason: "Check-in finalization for #{employee_person.display_name}",
             effective_date: Date.current)
    end

    before do
      sign_in_as(manager_person, company)
    end

    it 'displays the reason in the audit page' do
      visit audit_organization_employee_path(company, employee_person)
      
      expect(page).to have_content(snapshot.reason)
      expect(page).to have_content('MAAP Change History')
    end
  end
end

