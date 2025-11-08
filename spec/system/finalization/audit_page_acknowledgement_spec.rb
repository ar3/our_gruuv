require 'rails_helper'

RSpec.describe 'Audit Page Acknowledgement', type: :system do
  let(:organization) { create(:organization, :company) }
  let(:manager_person) { create(:person, full_name: 'Manager Guy') }
  let!(:manager_teammate) { create(:teammate, person: manager_person, organization: organization, can_manage_employment: true) }
  let!(:employee_person) { create(:person, full_name: 'John Doe', email: 'john@example.com') }
  let!(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }
  let!(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let!(:position_type) { create(:position_type, organization: organization, external_title: 'Software Engineer', position_major_level: position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let!(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let!(:manager_employment_tenure) do
    create(:employment_tenure,
      teammate: manager_teammate,
      position: position,
      company: organization,
      started_at: 2.years.ago
    )
  end
  let!(:employment_tenure) do
    create(:employment_tenure,
      teammate: employee_teammate,
      position: position,
      company: organization,
      manager: manager_person,
      started_at: 1.year.ago
    )
  end

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(manager_person).to receive(:can_manage_employment?).with(organization).and_return(true)
    allow(manager_person).to receive(:can_manage_employment?).and_return(true)
  end

  describe 'Employee acknowledgement on audit page' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(employee_person)
    end

    it 'shows pending acknowledgements section when employee has unacknowledged snapshots' do
      # Create a finalized snapshot that needs acknowledgement
      snapshot = create(:maap_snapshot,
        employee: employee_person,
        company: organization,
        created_by: manager_person,
        effective_date: Date.current,
        change_type: 'position_tenure',
        reason: 'Position check-in finalized',
        maap_data: { 'position_id' => position.id, 'official_rating' => 2 }
      )

      visit audit_organization_employee_path(organization, employee_person)
      
      # Should show pending acknowledgements section
      expect(page).to have_content('Pending Acknowledgements')
      expect(page).to have_content('1 finalized check-in that need your acknowledgement')
      expect(page).to have_content('Position check-in finalized')
      expect(page).to have_content('Manager Guy')
      expect(page).to have_button('Acknowledge Selected Check-ins')
    end

    it 'allows employee to acknowledge selected snapshots' do
      # Create multiple snapshots
      snapshot1 = create(:maap_snapshot,
        employee: employee_person,
        company: organization,
        created_by: manager_person,
        effective_date: Date.current,
        change_type: 'position_tenure',
        reason: 'First check-in finalized',
        maap_data: { 'position_id' => position.id, 'official_rating' => 2 }
      )
      
      snapshot2 = create(:maap_snapshot,
        employee: employee_person,
        company: organization,
        created_by: manager_person,
        effective_date: Date.current,
        change_type: 'position_tenure',
        reason: 'Second check-in finalized',
        maap_data: { 'position_id' => position.id, 'official_rating' => 1 }
      )

      visit audit_organization_employee_path(organization, employee_person)
      
      # Select both snapshots
      check "snapshot_#{snapshot1.id}"
      check "snapshot_#{snapshot2.id}"
      
      # Submit acknowledgement
      click_button 'Acknowledge Selected Check-ins'
      
      expect(page).to have_content('Successfully acknowledged 2 check-ins')
      
      # Verify snapshots are acknowledged
      snapshot1.reload
      snapshot2.reload
      expect(snapshot1.acknowledged?).to be true
      expect(snapshot2.acknowledged?).to be true
      
      # Should no longer show pending acknowledgements
      expect(page).not_to have_content('Pending Acknowledgements')
    end

    it 'shows select all functionality' do
      # Create multiple snapshots
      snapshot1 = create(:maap_snapshot,
        employee: employee_person,
        company: organization,
        created_by: manager_person,
        effective_date: Date.current,
        change_type: 'position_tenure',
        reason: 'First check-in finalized',
        maap_data: { 'position_id' => position.id, 'official_rating' => 2 }
      )
      
      snapshot2 = create(:maap_snapshot,
        employee: employee_person,
        company: organization,
        created_by: manager_person,
        effective_date: Date.current,
        change_type: 'position_tenure',
        reason: 'Second check-in finalized',
        maap_data: { 'position_id' => position.id, 'official_rating' => 1 }
      )

      visit audit_organization_employee_path(organization, employee_person)
      
      # Check "Select All" checkbox
      check 'select_all_snapshots'
      
      # Both individual checkboxes should be checked
      expect(page).to have_checked_field("snapshot_#{snapshot1.id}")
      expect(page).to have_checked_field("snapshot_#{snapshot2.id}")
    end

    it 'shows acknowledgement status in main history table' do
      # Create acknowledged and unacknowledged snapshots
      acknowledged_snapshot = create(:maap_snapshot,
        employee: employee_person,
        company: organization,
        created_by: manager_person,
        effective_date: Date.current,
        change_type: 'position_tenure',
        reason: 'Acknowledged check-in',
        maap_data: { 'position_id' => position.id, 'official_rating' => 2 },
        employee_acknowledged_at: 1.day.ago
      )
      
      pending_snapshot = create(:maap_snapshot,
        employee: employee_person,
        company: organization,
        created_by: manager_person,
        effective_date: Date.current,
        change_type: 'position_tenure',
        reason: 'Pending check-in',
        maap_data: { 'position_id' => position.id, 'official_rating' => 1 }
      )

      visit audit_organization_employee_path(organization, employee_person)
      
      # Should show acknowledgement status
      expect(page).to have_content('Acknowledged')
      expect(page).to have_content('Pending')
    end

    it 'does not show pending acknowledgements section when no pending snapshots' do
      # Create an acknowledged snapshot
      create(:maap_snapshot,
        employee: employee_person,
        company: organization,
        created_by: manager_person,
        effective_date: Date.current,
        change_type: 'position_tenure',
        reason: 'Acknowledged check-in',
        maap_data: { 'position_id' => position.id, 'official_rating' => 2 },
        employee_acknowledged_at: 1.day.ago
      )

      visit audit_organization_employee_path(organization, employee_person)
      
      # Should not show pending acknowledgements section
      expect(page).not_to have_content('Pending Acknowledgements')
    end
  end

  describe 'Manager view of audit page' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
    end

    it 'does not show acknowledgement functionality for managers' do
      # Create a snapshot
      create(:maap_snapshot,
        employee: employee_person,
        company: organization,
        created_by: manager_person,
        effective_date: Date.current,
        change_type: 'position_tenure',
        reason: 'Check-in finalized',
        maap_data: { 'position_id' => position.id, 'official_rating' => 2 }
      )

      visit audit_organization_employee_path(organization, employee_person)
      
      # Should not show pending acknowledgements section
      expect(page).not_to have_content('Pending Acknowledgements')
      expect(page).not_to have_content('Acknowledge Selected Check-ins')
      
      # Should not show acknowledgement column
      expect(page).not_to have_content('Acknowledgement')
    end
  end
end
