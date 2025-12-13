require 'rails_helper'

RSpec.describe 'Check-ins 1:1 Area Section', type: :system do
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

  it 'displays 1:1 section with link' do
    one_on_one_link = create(:one_on_one_link, teammate: employee_teammate, url: 'https://app.asana.com/0/123456/789')
    
    visit organization_company_teammate_check_ins_path(organization, employee_teammate)
    
    expect(page).to have_content('1:1 AREA')
    
    # Expand the one-on-one section to see details
    page.find('a[data-bs-target="#oneOnOneSection"]').click
    
    expect(page).to have_content('1:1 Source:')
    expect(page).to have_link('https://app.asana.com/0/123456/789', href: 'https://app.asana.com/0/123456/789')
    expect(page).to have_content('Asana Project')
    expect(page).to have_button('Manage 1:1 Area')
  end

  it 'displays empty state when no link exists' do
    visit organization_company_teammate_check_ins_path(organization, employee_teammate)
    
    expect(page).to have_content('1:1 AREA')
    
    # Expand the one-on-one section to see details
    page.find('a[data-bs-target="#oneOnOneSection"]').click
    
    expect(page).to have_content('No 1:1 link configured yet.')
    expect(page).to have_button('Manage 1:1 Area')
  end

  it 'shows deep integration status when configured' do
    one_on_one_link = create(:one_on_one_link, 
      teammate: employee_teammate, 
      url: 'https://app.asana.com/0/123456/789',
      deep_integration_config: { 'asana_project_id' => '123456' }
    )
    
    visit organization_company_teammate_check_ins_path(organization, employee_teammate)
    
    # Expand the one-on-one section to see details
    page.find('a[data-bs-target="#oneOnOneSection"]').click
    
    expect(page).to have_content('Integrated')
    expect(page).to have_content('Project ID: 123456')
    expect(page).to have_content('Deep Integration Active')
  end

  it 'redirects when clicking Manage 1:1 Area button' do
    visit organization_company_teammate_check_ins_path(organization, employee_teammate)
    
    # Expand the one-on-one section to see the button
    page.find('a[data-bs-target="#oneOnOneSection"]').click
    
    # Verify button is present
    expect(page).to have_button('Manage 1:1 Area')
    
    # Click the button
    click_button 'Manage 1:1 Area'
    
    # Should redirect to 1:1 management page
    expect(page).to have_current_path(/one_on_one_link/)
  end
end

