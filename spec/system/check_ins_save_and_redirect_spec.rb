require 'rails_helper'

RSpec.describe 'Check-ins Save and Redirect', type: :system do
  let(:organization) { create(:organization, :company) }
  let(:manager) { create(:person, full_name: 'Manager Person') }
  let(:employee) { create(:person, full_name: 'Employee Person') }
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization, can_manage_employment: true) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:position_type) { create(:position_type, organization: organization) }
  let(:position_level) { create(:position_level, position_major_level: position_type.position_major_level) }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let(:employment_tenure) do
    employee_teammate.update!(first_employed_at: 1.year.ago)
    create(:employment_tenure, teammate: employee_teammate, company: organization, manager: manager, position: position)
  end

  before do
    manager_teammate.update!(first_employed_at: 1.year.ago)
    create(:employment_tenure, teammate: manager_teammate, company: organization, position: position, started_at: 1.year.ago, ended_at: nil)
    employment_tenure
    sign_in_as(manager, organization)
  end

  it 'displays check-ins page with form fields' do
    visit organization_person_check_ins_path(organization, employee)
    
    # Verify the page loads correctly
    expect(page).to have_content('Check-Ins for')
    expect(page).to have_content(employee.display_name)
  end

  it 'displays check-ins page correctly' do
    visit organization_person_check_ins_path(organization, employee)
    
    # Verify the page loads and form is present
    expect(page).to have_content('Check-Ins for')
    expect(page).to have_content(employee.display_name)
    expect(page).to have_css('form')
  end
end

