require 'rails_helper'

RSpec.describe 'Finalization Complex Flow - Audit Reasons', type: :system do
  let(:company) { create(:organization, :company) }
  let(:manager_person) { create(:person, full_name: 'Manager') }
  let!(:manager_teammate) { CompanyTeammate.create!(person: manager_person, organization: company, can_manage_employment: true) }
  let!(:employee_person) { create(:person, full_name: 'John Doe', email: 'john@example.com') }
  let!(:employee_teammate) { CompanyTeammate.create!(person: employee_person, organization: company) }
  let!(:assignment) { create(:assignment, company: company, title: 'Test Assignment') }
  
  # Create employment tenures (required for authorization)
  let!(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let!(:title) { create(:title, company: company, external_title: 'Engineer', position_major_level: position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let!(:position) { create(:position, title: title, position_level: position_level) }
  let!(:manager_employment_tenure) do
    manager_teammate.update!(first_employed_at: 1.year.ago)
    create(:employment_tenure,
           teammate: manager_teammate,
           company: company,
           position: position,
           started_at: 1.year.ago,
           ended_at: nil)
  end
  let!(:employee_employment_tenure) do
    create(:employment_tenure,
           teammate: employee_teammate,
           company: company,
           position: position,
           manager: manager_person,
           started_at: 1.month.ago)
  end
  
  # Create assignment tenure
  let!(:assignment_tenure) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, started_at: 6.months.ago) }

  describe 'Stored reasons appear correctly on audit page' do
    let(:custom_reason) { 'Q4 2024 Performance Review' }
    let!(:snapshot) do
      create(:maap_snapshot,
             employee_company_teammate: employee_teammate,
             creator_company_teammate: manager_teammate,
             company: company,
             change_type: 'assignment_management',
             reason: custom_reason,
             effective_date: Date.current)
    end

    before do
      sign_in_as(manager_person, company)
    end

    it 'displays the custom reason in the audit page' do
      visit audit_organization_employee_path(company, employee_teammate)
      
      expect(page).to have_current_path(audit_organization_employee_path(company, employee_teammate))
      expect(page).to have_content(custom_reason)
      expect(page).to have_content('MAAP Change History')
    end

    it 'truncates long reasons correctly' do
      long_reason = 'A' * 100
      snapshot.update!(reason: long_reason)
      
      visit audit_organization_employee_path(company, employee_teammate)
      
      # The reason should be truncated to 50 characters in the table
      truncated = long_reason.truncate(50)
      expect(page).to have_content(truncated)
    end
  end

  describe 'Multiple finalizations with different reasons are distinguishable' do
    let!(:snapshot1) do
      create(:maap_snapshot,
             employee_company_teammate: employee_teammate,
             creator_company_teammate: manager_teammate,
             company: company,
             change_type: 'assignment_management',
             reason: 'Q4 2024 Performance Review',
             effective_date: 2.days.ago)
    end

    let!(:snapshot2) do
      create(:maap_snapshot,
             employee_company_teammate: employee_teammate,
             creator_company_teammate: manager_teammate,
             company: company,
             change_type: 'assignment_management',
             reason: 'Annual Check-in',
             effective_date: 1.day.ago)
    end

    before do
      sign_in_as(manager_person, company)
    end

    it 'shows both reasons distinctly on audit page' do
      visit audit_organization_employee_path(company, employee_teammate)
      
      expect(page).to have_content('Q4 2024 Performance Review')
      expect(page).to have_content('Annual Check-in')
      
      expect(page).to have_content('Q4 2024 Performance Review', count: 1)
      expect(page).to have_content('Annual Check-in', count: 1)
    end
  end
end
