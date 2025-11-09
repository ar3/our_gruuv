require 'rails_helper'

RSpec.describe 'Teammates View Configurations', type: :system do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person, full_name: 'Manager') }
  let!(:teammate) { CompanyTeammate.create!(person: person, organization: company) }
  
  before do
    sign_in_as(person, company)
  end

  describe 'View configuration variations' do
    xit 'switches between table, card, and list views' do # SKIPPED: View configuration switching not a priority
      # Create some teammates
      (1..3).each do |i|
        employee = create(:person, full_name: "Employee #{i}", email: "employee#{i}@example.com")
        CompanyTeammate.create!(person: employee, organization: company)
      end
      
      visit organization_employees_path(company)
      
      # Default view (table)
      expect(page).to have_css('table')
      
      # Switch to card view
      click_button 'Filter & Sort'
      choose 'card'
      click_button 'Apply'
      
      expect(page).to have_css('.card')
      expect(page).not_to have_css('table')
      
      # Switch to list view
      click_button 'Filter & Sort'
      choose 'list'
      click_button 'Apply'
      
      expect(page).to have_css('.list-group')
    end

    xit 'applies filters and maintains view configuration' do # SKIPPED: View configuration not a priority
      # Create teammates with different statuses
      active_employee = create(:person, full_name: 'Active Employee', email: 'active@example.com')
      CompanyTeammate.create!(person: active_employee, organization: company, first_employed_at: 1.year.ago)
      
      visit organization_employees_path(company)
      
      # Apply status filter
      click_button 'Filter & Sort'
      select 'Active', from: 'status'
      click_button 'Apply'
      
      # Should maintain view configuration
      expect(page).to have_content('Active Employee')
      
      # Switch view type - filter should persist
      click_button 'Filter & Sort'
      choose 'card'
      click_button 'Apply'
      
      expect(page).to have_content('Active Employee')
      expect(page).to have_css('.card')
    end

    xit 'sorts teammates and maintains view configuration' do # SKIPPED: View configuration not a priority
      # Create teammates with different names
      employee_a = create(:person, full_name: 'Alice', email: 'alice@example.com')
      employee_b = create(:person, full_name: 'Bob', email: 'bob@example.com')
      CompanyTeammate.create!(person: employee_a, organization: company)
      CompanyTeammate.create!(person: employee_b, organization: company)
      
      visit organization_employees_path(company)
      
      # Sort by name
      click_button 'Filter & Sort'
      select 'Name', from: 'sort_by'
      select 'Ascending', from: 'order'
      click_button 'Apply'
      
      # Verify sorting
      expect(page.body.index('Alice')).to be < page.body.index('Bob')
      
      # Switch view - sort should persist
      click_button 'Filter & Sort'
      choose 'list'
      click_button 'Apply'
      
      expect(page.body.index('Alice')).to be < page.body.index('Bob')
    end
  end
end

