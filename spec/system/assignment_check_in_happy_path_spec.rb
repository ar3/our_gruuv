require 'rails_helper'

RSpec.describe 'Assignment Check-In Happy Path', type: :system do
  let(:organization) { create(:organization, :company) }
  let(:manager_person) { create(:person, full_name: 'Manager Guy') }
  let!(:manager_teammate) { create(:teammate, person: manager_person, organization: organization, can_manage_employment: true) }
  let!(:employee_person) { create(:person, full_name: 'John Doe', email: 'john@example.com') }
  let!(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }
  let!(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let!(:position_type) { create(:position_type, organization: organization, external_title: 'Software Engineer', position_major_level: position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let!(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let!(:assignment1) { create(:assignment, company: organization, title: 'Database Design') }
  let!(:assignment2) { create(:assignment, company: organization, title: 'API Development') }
  let!(:assignment3) { create(:assignment, company: organization, title: 'Testing Strategy') }
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
  let!(:assignment_tenure1) do
    create(:assignment_tenure,
      teammate: employee_teammate,
      assignment: assignment1,
      anticipated_energy_percentage: 50,
      started_at: 1.month.ago
    )
  end
  
  let!(:assignment_tenure2) do
    create(:assignment_tenure,
      teammate: employee_teammate,
      assignment: assignment2,
      anticipated_energy_percentage: 70,
      started_at: 2.weeks.ago
    )
  end
  
  let!(:assignment_tenure3) do
    create(:assignment_tenure,
      teammate: employee_teammate,
      assignment: assignment3,
      anticipated_energy_percentage: 30,
      started_at: 1.week.ago
    )
  end

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager_person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(manager_person).to receive(:can_manage_employment?).with(organization).and_return(true)
    allow(manager_person).to receive(:can_manage_employment?).and_return(true)
  end

  it 'manager can complete one assignment while still being able to edit others' do
    visit organization_person_check_ins_path(organization, employee_person)
    
    # Verify we can see all three assignments
    expect(page).to have_content('Database Design')
    expect(page).to have_content('API Development')
    expect(page).to have_content('Testing Strategy')
    
    # Fill out form for the first assignment (Database Design)
    check_in1 = AssignmentCheckIn.find_by(teammate: employee_teammate, assignment: assignment1)
    check_in1_id = check_in1.id
    
    # Fill out manager fields for this assignment
    select 'Meeting', from: "check_ins[assignment_check_ins][#{check_in1_id}][manager_rating]"
    fill_in "check_ins[assignment_check_ins][#{check_in1_id}][manager_private_notes]", with: 'Great work on database design'
    
    # Find and click the complete radio button for this assignment
    # Note: Currently fails because radio buttons are not in the table row
    find("input[name='check_ins[assignment_check_ins][#{check_in1_id}][status]'][value='complete']").click
    
    # Submit
    click_button 'Save All Check-Ins'
    
    # Verify UX (not database!)
    expect(page).to have_content('Check-ins saved successfully')
    expect(page).to have_content('Great work on database design') # Shows saved data
    
    # Now verify that the OTHER two assignments are still editable
    check_in2 = AssignmentCheckIn.find_by(teammate: employee_teammate, assignment: assignment2)
    check_in2_id = check_in2.id
    
    check_in3 = AssignmentCheckIn.find_by(teammate: employee_teammate, assignment: assignment3)
    check_in3_id = check_in3.id
    
    # Should still be able to fill out API Development
    expect(page).to have_select("check_ins[assignment_check_ins][#{check_in2_id}][manager_rating]")
    expect(page).to have_field("check_ins[assignment_check_ins][#{check_in2_id}][manager_private_notes]")
    
    # Should still be able to fill out Testing Strategy
    expect(page).to have_select("check_ins[assignment_check_ins][#{check_in3_id}][manager_rating]")
    expect(page).to have_field("check_ins[assignment_check_ins][#{check_in3_id}][manager_private_notes]")
    
    # Fill out the second assignment while first is completed
    select 'Exceeding', from: "check_ins[assignment_check_ins][#{check_in2_id}][manager_rating]"
    fill_in "check_ins[assignment_check_ins][#{check_in2_id}][manager_private_notes]", with: 'Good progress on API'
    
    # Complete the second assignment too
    find("input[name='check_ins[assignment_check_ins][#{check_in2_id}][status]'][value='complete']").click
    
    click_button 'Save All Check-Ins'
    
    expect(page).to have_content('Check-ins saved successfully')
    expect(page).to have_content('Good progress on API')
    
    # Now verify we can toggle the first assignment back to draft
    # Find the draft radio button for the first completed assignment
    find("input[name='check_ins[assignment_check_ins][#{check_in1_id}][status]'][value='draft']").click
    
    click_button 'Save All Check-Ins'
    
    expect(page).to have_content('Check-ins saved successfully')
    
    # Verify we can now edit the first assignment again (it should be back to editable fields)
    select 'Exceeding', from: "check_ins[assignment_check_ins][#{check_in1_id}][manager_rating]"
    fill_in "check_ins[assignment_check_ins][#{check_in1_id}][manager_private_notes]", with: 'Actually even better'
    
    # Should be able to complete it again
    find("input[name='check_ins[assignment_check_ins][#{check_in1_id}][status]'][value='complete']").click
    click_button 'Save All Check-Ins'
    
    expect(page).to have_content('Check-ins saved successfully')
    expect(page).to have_content('Actually even better')
  end
end

