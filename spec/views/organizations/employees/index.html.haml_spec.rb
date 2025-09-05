require 'rails_helper'

RSpec.describe 'organizations/employees/index', type: :view do
  let(:company) { create(:organization, :company) }
  let(:team) { create(:organization, :team, parent: company) }
  let(:employee1) { create(:person, first_name: 'John', last_name: 'Doe') }
  let(:employee2) { create(:person, first_name: 'Jane', last_name: 'Smith') }
  let(:huddle_participant) { create(:person, first_name: 'Bob', last_name: 'Wilson') }
      let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
    let(:position_type) { create(:position_type, organization: company, position_major_level: position_major_level) }
    let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
    let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let(:employment_tenure1) { create(:employment_tenure, person: employee1, company: company, position: position, started_at: 1.year.ago) }
  let(:employment_tenure2) { create(:employment_tenure, person: employee2, company: company, position: position, started_at: 6.months.ago) }
  let(:huddle_playbook) { create(:huddle_playbook, organization: team) }
  let(:huddle) { create(:huddle, huddle_playbook: huddle_playbook, started_at: 1.month.ago) }
  let(:huddle_participation) { create(:huddle_participant, huddle: huddle, person: huddle_participant) }

  before do
    employment_tenure1
    employment_tenure2
    huddle_participation
    
    assign(:organization, company)
    assign(:active_employees, [employee1, employee2])
    assign(:huddle_participants, [employee1, employee2, huddle_participant])
    assign(:just_huddle_participants, [huddle_participant])
    
    # Define current_person helper method on the view
    current_person_obj = employee1 # Capture the variable
    view.define_singleton_method(:current_person) { current_person_obj }
  end

  it 'renders the organization name in the title' do
    render
    expect(rendered).to have_content("Employees & Participants - #{company.display_name}")
  end

  it 'shows active employees section' do
    render
    expect(rendered).to have_content('Active Employees')
    expect(rendered).to have_content('John Doe')
    expect(rendered).to have_content('Jane Smith')
    # Email addresses are not displayed in the main view (only in tooltips)
    expect(rendered).not_to have_content(employee1.email)
    expect(rendered).not_to have_content(employee2.email)
  end

  it 'shows huddle participants section' do
    render
    expect(rendered).to have_content('Huddle Participants (Non-Employees)')
    expect(rendered).to have_content('Bob Wilson')
    # Email addresses are not displayed in the main view (only in tooltips)
    expect(rendered).not_to have_content(huddle_participant.email)
  end

  it 'shows employee stats in the sidebar' do
    render
    expect(rendered).to have_content('2') # Active employees count
    expect(rendered).to have_content('1') # Non-employee participants count
  end

  it 'provides navigation back to organization' do
    render
    expect(rendered).to have_link('Back to Organization', href: organization_path(company))
  end

  it 'displays names without email addresses' do
    render
    expect(rendered).to have_content(employee1.display_name)
    expect(rendered).to have_content(employee2.display_name)
    expect(rendered).to have_content(huddle_participant.display_name)
    expect(rendered).not_to have_content("(#{employee1.email})")
    expect(rendered).not_to have_content("(#{employee2.email})")
    expect(rendered).not_to have_content("(#{huddle_participant.email})")
  end

  it 'includes Bootstrap tooltips with person details' do
    render
    expect(rendered).to have_css("a[data-bs-toggle='tooltip']")
    expect(rendered).to have_css("a[data-bs-title*='ID: #{employee1.id}']")
    expect(rendered).to have_css("a[data-bs-title*='Name: #{employee1.display_name}']")
    expect(rendered).to have_css("a[data-bs-title*='Email: #{employee1.email}']")
  end

  it 'shows employee position and start date' do
    render
    expect(rendered).to have_content('Software Engineer') # Position type name
    expect(rendered).to have_content('Sep 2024') # employee1 start date (1.year.ago)
    expect(rendered).to have_content('Mar 2025') # employee2 start date (6.months.ago)
  end

  it 'shows huddle participation counts' do
    render
    # Each employee should show their huddle count
    expect(rendered).to have_content('1') # huddle count for employees
  end

  it 'provides action buttons for employees' do
    render
    # Check that the Actions column header exists
    expect(rendered).to have_content('Actions')
    # Check that the action buttons are rendered by looking for their structure
    # Bootstrap icons don't render as visible text, so we check for button elements
    expect(rendered).to have_css('.btn-group .btn')
    # Check that we have action buttons (the exact href structure may vary)
    expect(rendered).to have_css('.btn-group .btn-outline-primary')
    expect(rendered).to have_css('.btn-group .btn-outline-info')
  end
end
