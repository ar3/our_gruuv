require 'rails_helper'

RSpec.describe 'Check-ins Goals Section', type: :system do
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

  it 'displays goals section with goals and check-ins' do
    # Create goals
    now_goal = create(:goal, 
      creator: employee_teammate, 
      owner: employee_teammate, 
      most_likely_target_date: Date.today + 1.month,
      started_at: 1.day.ago,
      title: 'Now Goal'
    )
    
    # Create check-in for the goal
    current_week_start = Date.current.beginning_of_week(:monday)
    create(:goal_check_in, 
      goal: now_goal, 
      check_in_week_start: current_week_start,
      confidence_percentage: 85
    )
    
    visit organization_person_check_ins_path(organization, employee)
    
    expect(page).to have_content('ACTIVE GOALS')
    expect(page).to have_content('Now Goal')
    expect(page).to have_content('85%')
    expect(page).to have_content('Up to date')
    expect(page).to have_button('Manage Goals & Confidence Ratings')
  end

  it 'shows new check-in needed when no current week check-in' do
    # Create goal
    goal = create(:goal, 
      creator: employee_teammate, 
      owner: employee_teammate, 
      most_likely_target_date: Date.today + 1.month,
      started_at: 1.day.ago,
      title: 'Goal Needing Check-in'
    )
    
    # Create old check-in (not current week)
    old_week_start = 1.week.ago.beginning_of_week(:monday)
    create(:goal_check_in, 
      goal: goal, 
      check_in_week_start: old_week_start,
      confidence_percentage: 75
    )
    
    visit organization_person_check_ins_path(organization, employee)
    
    expect(page).to have_content('Goal Needing Check-in')
    expect(page).to have_content('75%')
    expect(page).to have_content('New check-in needed')
  end

  it 'shows no check-in yet when goal has no check-ins' do
    # Create goal without check-ins
    goal = create(:goal, 
      creator: employee_teammate, 
      owner: employee_teammate, 
      most_likely_target_date: Date.today + 1.month,
      started_at: 1.day.ago,
      title: 'Goal Without Check-in'
    )
    
    visit organization_person_check_ins_path(organization, employee)
    
    expect(page).to have_content('Goal Without Check-in')
    expect(page).to have_content('No check-in yet')
  end

  it 'displays empty state when no goals' do
    visit organization_person_check_ins_path(organization, employee)
    
    expect(page).to have_content('ACTIVE GOALS')
    expect(page).to have_content('No active goals found.')
    expect(page).to have_button('Manage Goals & Confidence Ratings')
  end

  it 'redirects when clicking Manage Goals button' do
    visit organization_person_check_ins_path(organization, employee)
    
    # Verify button is present
    expect(page).to have_button('Manage Goals & Confidence Ratings')
    
    # Click the button
    click_button 'Manage Goals & Confidence Ratings'
    
    # Should redirect to goals page
    expect(page).to have_current_path(/goals/)
  end
end

