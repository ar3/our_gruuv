require 'rails_helper'

RSpec.describe 'Position Check-In Draft vs Complete - Comprehensive Test', type: :system, critical: true do
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
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(manager_person).to receive(:can_manage_employment?).with(organization).and_return(true)
    allow(manager_person).to receive(:can_manage_employment?).and_return(true)
  end

  describe 'Manager perspective' do
    it 'correctly handles draft vs complete status' do
      # Test 1: Save as draft should NOT mark as completed
      visit organization_person_check_ins_path(organization, employee_person)
      
      # Look for form fields in the in-progress partial
      within '.card.mb-4' do
        select '🔵 Praising/Trusting - Consistent strong performance', from: '_position_check_in_manager_rating'
        fill_in '_position_check_in_manager_private_notes', with: 'Manager draft notes'
        choose '_position_check_in_status_draft'
      end
      
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully.')
      
      position_check_in = PositionCheckIn.find_by(teammate: employee_teammate)
      expect(position_check_in.manager_completed_at).to be_nil, "Draft should not mark as completed"
      expect(position_check_in.manager_completed_by).to be_nil, "Draft should not set completed_by"
      expect(page).to have_content('📝 In Progress')
      
      # Test 2: Mark as complete SHOULD mark as completed
      within '.card.mb-4' do
        choose '_position_check_in_status_complete'
      end
      
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully.')
      
      position_check_in.reload
      expect(position_check_in.manager_completed_at).to be_present, "Complete should mark as completed"
      expect(position_check_in.manager_completed_by).to eq(manager_person), "Complete should set completed_by"
      expect(page).to have_content('Ready for Finalization')
      
      # Test 3: Change back to draft should uncomplete
      # Now we're in the completed view, so the radio buttons are in a different structure
      within '.card.mb-4' do
        choose '_position_check_in_status_draft'
      end
      
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully.')
      
      position_check_in.reload
      expect(position_check_in.manager_completed_at).to be_nil, "Changing to draft should uncomplete"
      expect(position_check_in.manager_completed_by).to be_nil, "Changing to draft should clear completed_by"
      expect(page).to have_content('📝 In Progress')
    end
  end

  describe 'Employee perspective' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(employee_person)
    end

    it 'correctly handles draft vs complete status' do
      # Test 1: Save as draft should NOT mark as completed
      visit organization_person_check_ins_path(organization, employee_person)
      
      within '.card.mb-4' do
        select '🟡 Actively Coaching - Mostly meeting expectations... Working on specific improvements', from: '_position_check_in_employee_rating'
        fill_in '_position_check_in_employee_private_notes', with: 'Employee draft notes'
        choose '_position_check_in_status_draft'
      end
      
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully.')
      
      position_check_in = PositionCheckIn.find_by(teammate: employee_teammate)
      expect(position_check_in.employee_completed_at).to be_nil, "Draft should not mark as completed"
      expect(page).to have_content('📝 In Progress')
      
      # Test 2: Mark as complete SHOULD mark as completed
      within '.card.mb-4' do
        choose '_position_check_in_status_complete'
      end
      
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully.')
      
      position_check_in.reload
      expect(position_check_in.employee_completed_at).to be_present, "Complete should mark as completed"
      expect(page).to have_content('Ready for Manager')
      
      # Test 3: Change back to draft should uncomplete
      within '.card.mb-4' do
        choose '_position_check_in_status_draft'
      end
      
      click_button 'Save All Check-Ins'
      expect(page).to have_content('Check-ins saved successfully.')
      
      position_check_in.reload
      expect(position_check_in.employee_completed_at).to be_nil, "Changing to draft should uncomplete"
      expect(page).to have_content('📝 In Progress')
    end
  end
end
