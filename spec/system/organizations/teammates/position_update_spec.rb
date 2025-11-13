require 'rails_helper'

RSpec.describe 'Position Update', type: :system, js: true do
  let(:company) { create(:organization, :company) }
  let(:manager_person) { create(:person, first_name: 'Manager', last_name: 'User') }
  let(:manager_teammate) { create(:teammate, person: manager_person, organization: company, can_manage_employment: true) }
  let(:employee_person) { create(:person, first_name: 'Employee', last_name: 'User') }
  let(:employee_teammate) { create(:teammate, person: employee_person, organization: company) }
  let(:current_manager) { create(:person, first_name: 'Current', last_name: 'Manager') }
  let(:new_manager) { create(:person, first_name: 'New', last_name: 'Manager') }
  let(:position) { create(:position) }
  let(:new_position) { create(:position) }
  let(:seat) { create(:seat, organization: company, position_type: position.position_type) }
  
  let(:current_tenure) do
    create(:employment_tenure,
      teammate: employee_teammate,
      company: company,
      position: position,
      manager: current_manager,
      seat: seat,
      employment_type: 'full_time',
      started_at: 6.months.ago
    )
  end

  before do
    current_tenure
    sign_in_and_visit(manager_person, company, organization_teammate_position_path(company, employee_teammate))
  end

  describe 'Simple submission' do
    it 'allows manager to update manager field' do
      expect(page).to have_content('Current Position')
      expect(page).to have_content(current_manager.display_name)
      
      select new_manager.display_name, from: 'employment_tenure_manager_id'
      click_button 'Update Position'
      
      expect(page).to have_content('Position information was successfully updated')
      expect(current_tenure.reload.ended_at).to eq(Date.current)
      
      new_tenure = EmploymentTenure.where(teammate: employee_teammate, company: company).order(:created_at).last
      expect(new_tenure.manager).to eq(new_manager)
    end
  end

  describe 'Complex submission' do
    let(:seat_for_new_position) { create(:seat, organization: company, position_type: new_position.position_type) }

    it 'allows manager to update all fields with multiple changes' do
      select new_manager.display_name, from: 'employment_tenure_manager_id'
      select new_position.display_name, from: 'employment_tenure_position_id'
      select 'Part Time', from: 'employment_tenure_employment_type'
      select seat_for_new_position.display_name, from: 'employment_tenure_seat_id'
      fill_in 'employment_tenure_reason', with: 'Promotion and schedule change'
      
      click_button 'Update Position'
      
      expect(page).to have_content('Position information was successfully updated')
      
      # Verify new tenure was created
      expect(current_tenure.reload.ended_at).to eq(Date.current)
      new_tenure = EmploymentTenure.where(teammate: employee_teammate, company: company).order(:created_at).last
      expect(new_tenure.manager).to eq(new_manager)
      expect(new_tenure.position).to eq(new_position)
      expect(new_tenure.employment_type).to eq('part_time')
      expect(new_tenure.seat).to eq(seat_for_new_position)
      
      # Verify maap_snapshot was created
      snapshot = MaapSnapshot.last
      expect(snapshot.change_type).to eq('position_tenure')
      expect(snapshot.reason).to eq('Promotion and schedule change')
    end

    it 'handles termination date update' do
      termination_date = Date.current + 2.weeks
      
      fill_in 'employment_tenure_termination_date', with: termination_date.strftime('%Y-%m-%d')
      fill_in 'employment_tenure_reason', with: 'End of contract'
      
      click_button 'Update Position'
      
      expect(page).to have_content('Position information was successfully updated')
      expect(current_tenure.reload.ended_at).to eq(termination_date)
      
      snapshot = MaapSnapshot.last
      expect(snapshot.effective_date).to eq(termination_date)
      expect(snapshot.reason).to eq('End of contract')
    end

    it 'shows validation error when reason provided without major changes' do
      # Only change seat (not a major change)
      new_seat = create(:seat, organization: company, position_type: position.position_type)
      select new_seat.display_name, from: 'employment_tenure_seat_id'
      fill_in 'employment_tenure_reason', with: 'Seat change reason'
      
      click_button 'Update Position'
      
      expect(page).to have_content('The reason field is only saved when a major change is made')
    end

    it 'handles form errors gracefully' do
      # Try to submit with invalid position
      select '', from: 'employment_tenure_position_id'
      click_button 'Update Position'
      
      expect(page).to have_content('Please fix the following errors')
    end
  end

  describe 'Permission-based UI' do
    context 'when user has can_manage_employment permission' do
      it 'shows enabled form fields' do
        expect(page).to have_select('employment_tenure_manager_id', disabled: false)
        expect(page).to have_select('employment_tenure_position_id', disabled: false)
        expect(page).to have_button('Update Position', disabled: false)
      end
    end

    context 'when user does not have can_manage_employment permission' do
      let(:manager_teammate) { create(:teammate, person: manager_person, organization: company, can_manage_employment: false) }

      it 'shows form but with disabled fields' do
        expect(page).to have_content('Current Position')
        expect(page).to have_select('employment_tenure_manager_id', disabled: true)
        expect(page).to have_select('employment_tenure_position_id', disabled: true)
        expect(page).to have_select('employment_tenure_employment_type', disabled: true)
        expect(page).to have_select('employment_tenure_seat_id', disabled: true)
        expect(page).to have_field('employment_tenure_termination_date', disabled: true)
        expect(page).to have_field('employment_tenure_reason', disabled: true)
      end

      it 'shows disabled button with warning icon and tooltip' do
        disabled_button = find('input[type="submit"][disabled]')
        expect(disabled_button).to be_present
        
        warning_icon = find('i.bi-exclamation-triangle.text-warning')
        expect(warning_icon).to be_present
        expect(warning_icon['data-bs-title']).to include('employment management permission')
      end
    end
  end
end

