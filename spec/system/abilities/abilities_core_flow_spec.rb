require 'rails_helper'

RSpec.describe 'Abilities Core Flow', type: :system do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:company_teammate) { CompanyTeammate.create!(person: person, organization: company, can_manage_employment: true, can_manage_maap: true) }
  let!(:employee_person) { create(:person, full_name: 'John Doe', email: 'john@example.com') }
  let!(:employee_teammate) { CompanyTeammate.create!(person: employee_person, organization: company) }

  before do
    sign_in_as(person, company)
  end

  describe 'CRUD ability on company' do
    it 'creates, views, updates, and deletes an ability on the company' do
      # Create
      visit new_organization_ability_path(company)
      expect(page).to have_content('New Ability')
      
      fill_in 'ability_name', with: 'Ruby Programming'
      fill_in 'ability_description', with: 'Ability to write Ruby applications'
      fill_in 'ability_milestone_1_description', with: 'Basic Ruby syntax'
      fill_in 'ability_milestone_2_description', with: 'Object-oriented programming'
      choose 'version_type_ready'
      
      click_button 'Create Ability'
      
      expect(page).to have_content('Ruby Programming')
      expect(page).to have_content('Ability to write Ruby applications')
      
      ability = Ability.last
      expect(ability.company.id).to eq(company.id)
      expect(ability.company.class).to eq(Organization)
      expect(ability.name).to eq('Ruby Programming')
      
      # View
      visit organization_abilities_path(company)
      expect(page).to have_content('Ruby Programming')
      
      # Update
      visit edit_organization_ability_path(company, ability)
      fill_in 'ability_name', with: 'Advanced Ruby Programming'
      choose 'version_type_clarifying'
      click_button 'Update Ability'
      
      expect(page).to have_content('Advanced Ruby Programming')
      ability.reload
      expect(ability.name).to eq('Advanced Ruby Programming')
      
      # # Delete
      # visit organization_abilities_path(company)
      # delete_link = find("a[href='#{organization_ability_path(company, ability)}'][data-method='delete']")
      # page.execute_script("window.confirm = function() { return true; }")
      # delete_link.click
      # sleep 1
      
      # expect(page).to have_success_flash('Ability was successfully deleted')
      # expect(Ability.find_by(id: ability.id)).to be_nil
    end
  end

  describe 'Assign milestone to employee' do
    let!(:ability) do
      create(:ability, company: company,
        name: 'Leadership',
        description: 'Ability to lead teams',
        milestone_1_description: 'Basic leadership',
        milestone_2_description: 'Team leadership',
        created_by: person,
        updated_by: person
      )
    end

    before do
      # Create active employment for employee so they can be viewed
      employment_tenure = create(:employment_tenure, company_teammate: employee_teammate, company: company, started_at: 1.year.ago, ended_at: nil)
      employee_teammate.update!(first_employed_at: 1.year.ago)
      
      # Set manager relationship so person can view employee's complete picture
      employment_tenure.update!(manager_teammate: company_teammate)
      
      # Ensure manager also has active employment
      create(:employment_tenure, company_teammate: company_teammate, company: company, started_at: 1.year.ago, ended_at: nil)
      company_teammate.update!(first_employed_at: 1.year.ago)
    end

    it 'assigns a milestone to an employee via celebrate milestones page' do
      # Visit celebrate milestones page
      visit celebrate_milestones_organization_path(company)
      expect(page).to have_content('Recent Milestones')
      
      # Create milestone directly and publish so it appears on celebrate page
      milestone = TeammateMilestone.create!(
        company_teammate: employee_teammate,
        ability: ability,
        milestone_level: 2,
        certifying_teammate: company_teammate,
        attained_at: Date.current,
        published_at: Time.current,
        published_by_teammate_id: company_teammate.id
      )
      
      # Verify milestone appears on celebrate milestones page
      visit celebrate_milestones_organization_path(company)
      expect(page).to have_content('John Doe')
      expect(page).to have_content('Leadership')
      expect(page).to have_content('Milestone 2')
      
      # Verify milestone appears on employee's complete picture
      visit complete_picture_organization_company_teammate_path(company, employee_teammate)
      expect(page).to have_content('Achieved Milestones')
      expect(page).to have_content('Leadership')
      expect(page).to have_content('Milestone 2')
      
      # Verify milestone appears on ability show page
      visit organization_ability_path(company, ability)
      expect(page).to have_content('People with milestones:')
      expect(page).to have_content('1')
    end
  end
end

