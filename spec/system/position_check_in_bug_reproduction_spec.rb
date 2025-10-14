require 'rails_helper'

RSpec.describe 'Position Check-In Bug Reproduction', type: :system, critical: true do
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

  it 'reproduces the exact bug: manager saves as draft but check-in is marked as completed' do
    # Step 1: Visit check-ins page as manager
    visit organization_person_check_ins_path(organization, employee_person)
    
    expect(page).to have_content('Check-Ins for John Doe')
    expect(page).to have_content('View Mode: Manager')

    # Step 2: Verify initial state - no check-in should exist yet
    initial_check_ins = PositionCheckIn.where(teammate: employee_teammate)
    puts "DEBUG: Initial check-ins count: #{initial_check_ins.count}"
    
    # Step 3: Fill in manager assessment and select "Save as Draft"
    within '.card.mb-4' do
      select '🔵 Praising/Trusting - Consistent strong performance', from: '_position_check_in_manager_rating'
      fill_in '_position_check_in_manager_private_notes', with: 'Manager draft notes - should NOT be completed'
      choose '_position_check_in_status_draft'  # This should NOT complete the check-in
    end
    
    # Step 4: Click save
    click_button 'Save All Check-Ins'

    # Step 5: Verify the bug - check-in should NOT be completed
    expect(page).to have_content('Check-ins saved successfully.')
    
    # Step 6: Check database state
    position_check_in = PositionCheckIn.find_by(teammate: employee_teammate)
    expect(position_check_in).to be_present, "Check-in should be created"
    
    puts "DEBUG: After save - Manager completed_at: #{position_check_in.manager_completed_at}"
    puts "DEBUG: After save - Manager completed_by: #{position_check_in.manager_completed_by}"
    puts "DEBUG: After save - Manager rating: #{position_check_in.manager_rating}"
    puts "DEBUG: After save - Manager notes: #{position_check_in.manager_private_notes}"
    
    # This should FAIL if the bug exists
    expect(position_check_in.manager_completed_at).to be_nil, 
      "BUG: Manager should NOT be marked as completed when saving as draft. " \
      "Expected nil, got #{position_check_in.manager_completed_at}"
    
    expect(position_check_in.manager_completed_by).to be_nil,
      "BUG: Manager should NOT be marked as completed by when saving as draft. " \
      "Expected nil, got #{position_check_in.manager_completed_by}"
    
    # Step 7: Verify UI state
    expect(page).to have_content('📝 In Progress')
    expect(page).not_to have_content('⏳ Waiting for Employee')
  end
end
