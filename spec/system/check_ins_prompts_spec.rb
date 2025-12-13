require 'rails_helper'

RSpec.describe 'Check-ins Prompts Section', type: :system do
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

  it 'displays prompts section with prompts' do
    # Find or create company teammate for employee
    company = organization.root_company || organization
    company_teammate = CompanyTeammate.find_or_create_by(person: employee, organization: company) do |ct|
      ct.type = 'CompanyTeammate'
    end
    
    # Create prompt template
    prompt_template = create(:prompt_template, company: company, title: 'Weekly Reflection')
    
    # Create prompts
    prompt = create(:prompt, 
      company_teammate: company_teammate, 
      prompt_template: prompt_template,
      created_at: 1.day.ago
    )
    
    visit organization_company_teammate_check_ins_path(organization, employee_teammate)
    
    expect(page).to have_content('PROMPTS / REFLECTIONS')
    expect(page).to have_content('1 open prompt')
    
    # Expand the prompts section to see details
    page.find('a[data-bs-target="#promptsSection"]').click
    
    expect(page).to have_content('Weekly Reflection')
    expect(page).to have_content('Open')
    expect(page).to have_button('View All Prompts')
  end

  it 'displays empty state when no prompts' do
    # Find or create company teammate for employee
    company = organization.root_company || organization
    CompanyTeammate.find_or_create_by(person: employee, organization: company) do |ct|
      ct.type = 'CompanyTeammate'
    end
    
    visit organization_company_teammate_check_ins_path(organization, employee_teammate)
    
    expect(page).to have_content('PROMPTS / REFLECTIONS')
    
    # Expand the prompts section to see details
    page.find('a[data-bs-target="#promptsSection"]').click
    
    expect(page).to have_content('No recent prompts to display.')
    expect(page).to have_button('View All Prompts')
  end

  it 'shows closed prompts with closed badge' do
    # Find or create company teammate for employee
    company = organization.root_company || organization
    company_teammate = CompanyTeammate.find_or_create_by(person: employee, organization: company) do |ct|
      ct.type = 'CompanyTeammate'
    end
    
    # Create prompt template
    prompt_template = create(:prompt_template, company: company, title: 'Completed Reflection')
    
    # Create closed prompt
    prompt = create(:prompt, 
      company_teammate: company_teammate, 
      prompt_template: prompt_template,
      created_at: 1.day.ago,
      closed_at: 1.hour.ago
    )
    
    visit organization_company_teammate_check_ins_path(organization, employee_teammate)
    
    # Expand the prompts section to see details
    page.find('a[data-bs-target="#promptsSection"]').click
    
    expect(page).to have_content('Completed Reflection')
    expect(page).to have_content('Closed')
    expect(page).not_to have_content('Open')
  end

  it 'limits display to last 3 prompts' do
    # Find or create company teammate for employee
    company = organization.root_company || organization
    company_teammate = CompanyTeammate.find_or_create_by(person: employee, organization: company) do |ct|
      ct.type = 'CompanyTeammate'
    end
    
    # Create 5 prompt templates (one per prompt to avoid validation error)
    templates = 5.times.map { create(:prompt_template, company: company) }
    
    # Create 5 prompts
    5.times do |i|
      create(:prompt, 
        company_teammate: company_teammate, 
        prompt_template: templates[i],
        created_at: (i + 1).days.ago
      )
    end
    
    visit organization_company_teammate_check_ins_path(organization, employee_teammate)
    
    # Should show count of all open prompts (5)
    expect(page).to have_content('5 open prompts')
    
    # Expand the prompts section to see details
    page.find('a[data-bs-target="#promptsSection"]').click
    
    # Verify only 3 prompts are displayed in the list
    expect(page).to have_css('.list-group-item', count: 3)
  end

  it 'redirects when clicking View All Prompts' do
    # Find or create company teammate for employee
    company = organization.root_company || organization
    company_teammate = CompanyTeammate.find_or_create_by(person: employee, organization: company) do |ct|
      ct.type = 'CompanyTeammate'
    end
    
    visit organization_company_teammate_check_ins_path(organization, employee_teammate)
    
    # Expand the prompts section to see the button
    page.find('a[data-bs-target="#promptsSection"]').click
    
    # Verify button is present
    expect(page).to have_button('View All Prompts')
    
    # Click the button
    click_button 'View All Prompts'
    
    # Should redirect to prompts page
    expect(page).to have_current_path(/prompts/)
  end
end

