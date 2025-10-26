require 'rails_helper'

RSpec.describe 'Aspiration Check-In Happy Path', type: :system do
  let(:organization) { create(:organization, :company) }
  let(:manager_person) { create(:person, full_name: 'Manager Guy') }
  let!(:manager_teammate) { create(:teammate, person: manager_person, organization: organization, can_manage_employment: true) }
  let!(:employee_person) { create(:person, full_name: 'John Doe', email: 'john@example.com') }
  let!(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }
  let!(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let!(:position_type) { create(:position_type, organization: organization, external_title: 'Software Engineer', position_major_level: position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let!(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let!(:aspiration1) { create(:aspiration, organization: organization, name: 'Learning React') }
  let!(:aspiration2) { create(:aspiration, organization: organization, name: 'Mastering TypeScript') }
  let!(:aspiration3) { create(:aspiration, organization: organization, name: 'Leading Projects') }
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

  it 'manager can complete one aspiration while still being able to edit others' do
    visit organization_person_check_ins_path(organization, employee_person)
    
    # Verify we can see all three aspirations
    expect(page).to have_content('Learning React')
    expect(page).to have_content('Mastering TypeScript')
    expect(page).to have_content('Leading Projects')
    
    # Fill out form for the first aspiration (Learning React)
    check_in1 = AspirationCheckIn.find_by(teammate: employee_teammate, aspiration: aspiration1)
    check_in1_id = check_in1.id
    
    # Fill out manager fields for this aspiration
    select 'Meeting', from: "check_ins[aspiration_check_ins][#{check_in1_id}][manager_rating]"
    fill_in "check_ins[aspiration_check_ins][#{check_in1_id}][manager_private_notes]", with: 'Great progress on React'
    
    # Find and click the complete radio button for this aspiration
    find("input[name='check_ins[aspiration_check_ins][#{check_in1_id}][status]'][value='complete']").click
    
    # Submit
    click_button 'Save All Check-Ins'
    
    # Verify UX (not database!)
    expect(page).to have_content('Check-ins saved successfully')
    expect(page).to have_content('Great progress on React') # Shows saved data
    
    # Now verify that the OTHER two aspirations are still editable
    check_in2 = AspirationCheckIn.find_by(teammate: employee_teammate, aspiration: aspiration2)
    check_in2_id = check_in2.id
    
    check_in3 = AspirationCheckIn.find_by(teammate: employee_teammate, aspiration: aspiration3)
    check_in3_id = check_in3.id
    
    # Should still be able to fill out Mastering TypeScript
    expect(page).to have_select("check_ins[aspiration_check_ins][#{check_in2_id}][manager_rating]")
    expect(page).to have_field("check_ins[aspiration_check_ins][#{check_in2_id}][manager_private_notes]")
    
    # Should still be able to fill out Leading Projects
    expect(page).to have_select("check_ins[aspiration_check_ins][#{check_in3_id}][manager_rating]")
    expect(page).to have_field("check_ins[aspiration_check_ins][#{check_in3_id}][manager_private_notes]")
    
    # Fill out the second aspiration while first is completed
    select 'Exceeding', from: "check_ins[aspiration_check_ins][#{check_in2_id}][manager_rating]"
    fill_in "check_ins[aspiration_check_ins][#{check_in2_id}][manager_private_notes]", with: 'Excellent TypeScript skills'
    
    # Complete the second aspiration too
    find("input[name='check_ins[aspiration_check_ins][#{check_in2_id}][status]'][value='complete']").click
    
    click_button 'Save All Check-Ins'
    
    expect(page).to have_content('Check-ins saved successfully')
    expect(page).to have_content('Excellent TypeScript skills')
    
    # Now verify we can toggle the first aspiration back to draft
    # Find the draft radio button for the first completed aspiration
    find("input[name='check_ins[aspiration_check_ins][#{check_in1_id}][status]'][value='draft']").click
    
    click_button 'Save All Check-Ins'
    
    expect(page).to have_content('Check-ins saved successfully')
    
    # Verify we can now edit the first aspiration again (it should be back to editable fields)
    select 'Exceeding', from: "check_ins[aspiration_check_ins][#{check_in1_id}][manager_rating]"
    fill_in "check_ins[aspiration_check_ins][#{check_in1_id}][manager_private_notes]", with: 'Even better progress'
    
    # Should be able to complete it again
    find("input[name='check_ins[aspiration_check_ins][#{check_in1_id}][status]'][value='complete']").click
    click_button 'Save All Check-Ins'
    
    expect(page).to have_content('Check-ins saved successfully')
    expect(page).to have_content('Even better progress')
  end
end

