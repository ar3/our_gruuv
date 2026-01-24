require 'rails_helper'

RSpec.describe 'Assignment Detail Page Check-In', type: :system do
  let(:company) { create(:organization, :company) }
  let(:manager_person) { create(:person, full_name: 'Manager') }
  let!(:manager_teammate) do
    CompanyTeammate.create!(
      person: manager_person,
      organization: company,
      can_manage_employment: true,
      first_employed_at: 2.years.ago
    )
  end
  let!(:employee_person) { create(:person, full_name: 'John Doe', email: 'john@example.com') }
  let!(:employee_teammate) { CompanyTeammate.create!(person: employee_person, organization: company) }
  let!(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let!(:title) { create(:title, organization: company, external_title: 'Engineer', position_major_level: position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let!(:position) { create(:position, title: title, position_level: position_level) }
  let!(:employment_tenure) do
    create(:employment_tenure,
      teammate: employee_teammate,
      position: position,
      company: company,
      manager: manager_person,
      started_at: 1.year.ago
    )
  end
  let!(:assignment) { create(:assignment, company: company, title: 'Test Assignment') }
  let!(:assignment_tenure) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, started_at: 6.months.ago) }

  describe 'Employee view' do
    before do
      sign_in_as(employee_person, company)
    end

    it 'shows employee fields and allows saving check-in' do
      visit organization_teammate_assignment_path(company, employee_teammate, assignment)
      
      expect(page).to have_content('Test Assignment')
      expect(page).to have_content('John Doe')
      
      # Verify forecasted energy field is NOT present
      expect(page).not_to have_content('Forecasted Energy')
      expect(page).not_to have_field('tenure', type: 'select')
      
      # Verify employee fields are present
      expect(page).to have_content('Actual Energy')
      expect(page).to have_content('Personal Alignment')
      expect(page).to have_content('My Rating')
      expect(page).to have_content('Private Notes')
      
      # Verify manager fields are NOT present
      expect(page).not_to have_content('Manager Rating')
      expect(page).not_to have_content('Manager Notes')
      
      # Fill out employee check-in fields
      check_in = AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment)
      
      # Fill form with nested format
      select '75%', from: "check_ins[assignment_check_ins][#{check_in.id}][actual_energy_percentage]"
      select 'Love', from: "check_ins[assignment_check_ins][#{check_in.id}][employee_personal_alignment]"
      select '🟢 Exceeding', from: "check_ins[assignment_check_ins][#{check_in.id}][employee_rating]"
      fill_in "check_ins[assignment_check_ins][#{check_in.id}][employee_private_notes]", with: 'Great assignment!'
      choose "check_ins_assignment_check_ins_#{check_in.id}_status_complete"
      
      # Submit form
      click_button 'Update Check-in'
      
      # When check-in is marked complete, it redirects to finalization page
      expect(page).to have_current_path(organization_company_teammate_finalization_path(company, employee_teammate))
      
      # Should see success message or finalization content
      expect(page).to have_content(/Check-in|Finalization|ready/i)
      
      # Verify data was saved
      check_in.reload
      expect(check_in.actual_energy_percentage).to eq(75)
      expect(check_in.employee_personal_alignment).to eq('love')
      expect(check_in.employee_rating).to eq('exceeding')
      expect(check_in.employee_private_notes).to eq('Great assignment!')
      expect(check_in.employee_completed_at).to be_present
    end
  end

  describe 'Manager view' do
    before do
      sign_in_as(manager_person, company)
    end

    it 'shows manager fields and allows saving check-in' do
      visit organization_teammate_assignment_path(company, employee_teammate, assignment)
      
      expect(page).to have_content('Test Assignment')
      expect(page).to have_content('John Doe')
      
      # Verify forecasted energy field is NOT present
      expect(page).not_to have_content('Forecasted Energy')
      expect(page).not_to have_field('tenure', type: 'select')
      
      # Verify manager fields are present
      expect(page).to have_content('Manager Rating')
      expect(page).to have_content('Manager Notes')
      
      # Verify employee fields are NOT present
      expect(page).not_to have_content('Actual Energy')
      expect(page).not_to have_content('Personal Alignment')
      expect(page).not_to have_content('My Rating')
      expect(page).not_to have_content('Private Notes')
      
      # Fill out manager check-in fields
      check_in = AssignmentCheckIn.find_or_create_open_for(employee_teammate, assignment)
      
      # Fill form with nested format
      select '🔵 Meeting', from: "check_ins[assignment_check_ins][#{check_in.id}][manager_rating]"
      fill_in "check_ins[assignment_check_ins][#{check_in.id}][manager_private_notes]", with: 'Good work!'
      choose "check_ins_assignment_check_ins_#{check_in.id}_status_complete"
      
      # Submit form
      click_button 'Update Check-in'
      
      # When check-in is marked complete, it redirects to finalization page
      expect(page).to have_current_path(organization_company_teammate_finalization_path(company, employee_teammate))
      
      # Should see success message or finalization content
      expect(page).to have_content(/Check-in|Finalization|ready/i)
      
      # Verify data was saved
      check_in.reload
      expect(check_in.manager_rating).to eq('meeting')
      expect(check_in.manager_private_notes).to eq('Good work!')
      expect(check_in.manager_completed_at).to be_present
      expect(check_in.manager_completed_by_teammate).to eq(manager_teammate)
    end
  end
end

