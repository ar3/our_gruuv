require 'rails_helper'

RSpec.describe 'Check-ins Stories Section', type: :system do
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

  it 'displays stories section with observations' do
    # Create observations about the employee
    observation1 = create(:observation, 
      observer: manager, 
      company: organization, 
      observed_at: 10.days.ago, 
      published_at: 10.days.ago,
      story: 'This is a test observation story about the employee.'
    )
    observation2 = create(:observation, 
      observer: manager, 
      company: organization, 
      observed_at: 20.days.ago, 
      published_at: 20.days.ago,
      story: 'Another observation story.'
    )
    
    create(:observee, observation: observation1, teammate: employee_teammate)
    create(:observee, observation: observation2, teammate: employee_teammate)
    
    visit organization_person_check_ins_path(organization, employee)
    
    expect(page).to have_content("STORIES ABOUT #{employee.first_name.upcase}")
    expect(page).to have_content('2 observations')
    expect(page).to have_content('in the last 45 days')
    expect(page).to have_content(manager.display_name)
    expect(page).to have_content('This is a test observation story')
    expect(page).to have_button('View All Observations')
  end

  it 'displays empty state when no observations' do
    visit organization_person_check_ins_path(organization, employee)
    
    expect(page).to have_content("STORIES ABOUT #{employee.first_name.upcase}")
    expect(page).to have_content('0 observations')
    expect(page).to have_content('No recent observations to display.')
    expect(page).to have_button('View All Observations')
  end

  it 'limits display to last 3 observations' do
    # Create 5 observations
    5.times do |i|
      observation = create(:observation, 
        observer: manager, 
        company: organization, 
        observed_at: (i + 1).days.ago, 
        published_at: (i + 1).days.ago,
        story: "Observation #{i + 1}"
      )
      create(:observee, observation: observation, teammate: employee_teammate)
    end
    
    visit organization_person_check_ins_path(organization, employee)
    
    expect(page).to have_content('5 observations')
    # Should only show last 3
    expect(page).to have_content('Observation 1')
    expect(page).to have_content('Observation 2')
    expect(page).to have_content('Observation 3')
    # Should not show older ones
    expect(page).not_to have_content('Observation 4')
    expect(page).not_to have_content('Observation 5')
  end

  it 'redirects when clicking View All Observations' do
    # Create an observation
    observation = create(:observation, 
      observer: manager, 
      company: organization, 
      observed_at: 10.days.ago, 
      published_at: 10.days.ago
    )
    create(:observee, observation: observation, teammate: employee_teammate)
    
    visit organization_person_check_ins_path(organization, employee)
    
    # Verify button is present
    expect(page).to have_button('View All Observations')
    
    # Click the View All Observations button
    click_button 'View All Observations'
    
    # Should redirect to observations page
    expect(page).to have_current_path(/observations/)
  end
end

