require 'rails_helper'

RSpec.describe 'MAAP Snapshot Acknowledgement', type: :system do
  let(:company) { create(:organization, :company) }
  let(:manager_person) { create(:person, full_name: 'Manager') }
  let!(:manager_teammate) { CompanyTeammate.create!(person: manager_person, organization: company, can_manage_employment: true) }
  let!(:employee_person) { create(:person, full_name: 'John Doe', email: 'john@example.com') }
  let!(:employee_teammate) { CompanyTeammate.create!(person: employee_person, organization: company) }
  let!(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let!(:position_type) { create(:position_type, organization: company, external_title: 'Engineer', position_major_level: position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let!(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let!(:employment_tenure) do
    create(:employment_tenure,
      teammate: employee_teammate,
      position: position,
      company: company,
      started_at: 1.year.ago
    )
  end
  let!(:assignment) { create(:assignment, company: company, title: 'Assignment 1') }
  let!(:assignment_tenure) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, started_at: 6.months.ago) }

  describe 'Employee viewing and acknowledging maap snapshots' do
    before do
      sign_in_as(employee_person, company)
    end

    xit 'can see and acknowledge position tenure snapshot' do # SKIPPED: For now
      # Create snapshot for position tenure change
      snapshot = MaapSnapshot.create!(
        employee_company_teammate: employee_teammate,
        company: company,
        change_type: 'position_tenure',
        reason: 'Test position tenure change',
        maap_data: {
          employment_tenure: {
            position_id: position.id,
            started_at: 1.year.ago
          }
        },
        effective_date: Date.current,
        created_by: manager_person
      )
      
      visit audit_organization_employee_path(company, employee_person)
      
      # Should see pending snapshot
      expect(page).to have_content('Pending Acknowledgements')
      expect(page).to have_content('position tenure')
      
      # Acknowledge snapshot - use more specific selector to avoid ambiguity
      check_box = find("input[type='checkbox'][value='#{snapshot.id}'].snapshot-checkbox")
      check_box.check
      
      click_button 'Acknowledge Selected Check-ins'
      
      # Verify snapshot was acknowledged
      snapshot.reload
      expect(snapshot.employee_acknowledged_at).to be_present
      
      # Should no longer appear in pending list
      visit audit_organization_employee_path(company, employee_person)
      expect(page).not_to have_content('Position Tenure')
    end

    xit 'can see and acknowledge assignment tenure snapshot' do # SKIPPED: For now
      # Create snapshot for assignment tenure change
      snapshot = MaapSnapshot.create!(
        employee_company_teammate: employee_teammate,
        company: company,
        change_type: 'assignment_management',
        reason: 'Test assignment tenure change',
        maap_data: {
          assignments: [{
            id: assignment.id,
            title: assignment.title,
            tenure: {
              started_at: 6.months.ago,
              anticipated_energy_percentage: 50
            }
          }]
        },
        effective_date: Date.current,
        created_by: manager_person
      )
      
      visit audit_organization_employee_path(company, employee_person)
      
      # Should see pending snapshot
      expect(page).to have_content('Assignment Management')
      
      # Acknowledge snapshot - use more specific selector to avoid ambiguity
      check_box = find("input[type='checkbox'][value='#{snapshot.id}'].snapshot-checkbox")
      check_box.check
      
      click_button 'Acknowledge Selected Check-ins'
      
      # Verify snapshot was acknowledged
      snapshot.reload
      expect(snapshot.employee_acknowledged_at).to be_present
    end

    xit 'can acknowledge multiple snapshots at once' do # SKIPPED: For now
      # Create multiple snapshots
      snapshot1 = MaapSnapshot.create!(
        employee_company_teammate: employee_teammate,
        company: company,
        change_type: 'position_tenure',
        reason: 'Test position tenure change 1',
        maap_data: { employment_tenure: { position_id: position.id } },
        effective_date: Date.current,
        created_by: manager_person
      )
      
      snapshot2 = MaapSnapshot.create!(
        employee_company_teammate: employee_teammate,
        company: company,
        change_type: 'assignment_management',
        reason: 'Test assignment tenure change 2',
        maap_data: { assignments: [] },
        effective_date: Date.current,
        created_by: manager_person
      )
      
      visit audit_organization_employee_path(company, employee_person)
      
      # Select all using the checkbox
      check 'select_all_snapshots'
      
      click_button 'Acknowledge Selected Check-ins'
      
      # Verify both were acknowledged
      snapshot1.reload
      snapshot2.reload
      expect(snapshot1.employee_acknowledged_at).to be_present
      expect(snapshot2.employee_acknowledged_at).to be_present
    end
  end
end

