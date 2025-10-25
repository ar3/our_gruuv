require 'rails_helper'

RSpec.describe 'Position Check-In Happy Path', type: :system do
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

  it 'manager can complete a check-in and see success message' do
    visit organization_person_check_ins_path(organization, employee_person)
    
    # Fill out form
    select '🔵 Praising/Trusting - Consistent strong performance', from: 'check_ins[position_check_in][manager_rating]'
    fill_in 'check_ins[position_check_in][manager_private_notes]', with: 'Great work'
    choose 'Complete'
    
    # Submit
    click_button 'Save All Check-Ins'
    
    # Verify UX (not database!)
    expect(page).to have_content('Check-ins saved successfully')
    expect(page).to have_content('Ready for Finalization')
    expect(page).to have_content('Great work') # Shows saved data
  end
end
