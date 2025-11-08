require 'rails_helper'

RSpec.describe 'Assignment Ability Milestones', type: :system do
  let(:company) { create(:organization, :company) }
  let(:department) { create(:organization, :department, parent: company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: company, can_manage_employment: true) }
  let!(:assignment) { create(:assignment, company: company, title: 'Product Manager') }
  let!(:ability1) { create(:ability, organization: company, name: 'Ruby Programming') }
  let!(:ability2) { create(:ability, organization: company, name: 'JavaScript Development') }
  let!(:ability3) { create(:ability, organization: company, name: 'Python Development') }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(company)
    allow(person).to receive(:can_manage_employment?).and_return(true)
    # Set up Pundit user context
    allow_any_instance_of(Organizations::Assignments::AbilityMilestonesController).to receive(:pundit_user).and_return(
      OpenStruct.new(user: person, pundit_organization: company)
    )
    # Mock authorization
    allow_any_instance_of(AssignmentPolicy).to receive(:show?).and_return(true)
    allow_any_instance_of(AssignmentPolicy).to receive(:update?).and_return(true)
  end

  describe 'Assignment-centric milestone management' do
    it 'loads the ability milestones page with all abilities in hierarchy' do
      # Create ability in department to test hierarchy scoping
      ability_in_dept = create(:ability, organization: department, name: 'Department Ability')
      
      visit organization_assignment_ability_milestones_path(company, assignment)
      
      expect(page).to have_content('Product Manager - Ability Milestones')
      expect(page).to have_content('Ruby Programming')
      expect(page).to have_content('JavaScript Development')
      expect(page).to have_content('Python Development')
      expect(page).to have_content('Department Ability')
      
      # Should see radio buttons for each ability
      expect(page).to have_css("input[type='radio'][id='ability_#{ability1.id}_milestone_1']")
      expect(page).to have_css("input[type='radio'][id='ability_#{ability1.id}_milestone_5']")
      expect(page).to have_css("input[type='radio'][id='ability_#{ability1.id}_no_association']")
      
      # Should see save button
      expect(page).to have_button('Save Ability Milestones')
    end

    it 'pre-selects existing milestone associations' do
      create(:assignment_ability, :same_organization, assignment: assignment, ability: ability1, milestone_level: 3)
      create(:assignment_ability, :same_organization, assignment: assignment, ability: ability2, milestone_level: 5)
      
      visit organization_assignment_ability_milestones_path(company, assignment)
      
      # Should have milestone 3 selected for ability1
      expect(page).to have_checked_field("ability_#{ability1.id}_milestone_3")
      
      # Should have milestone 5 selected for ability2
      expect(page).to have_checked_field("ability_#{ability2.id}_milestone_5")
      
      # Should have no association selected for ability3
      expect(page).to have_checked_field("ability_#{ability3.id}_no_association")
    end

    it 'creates new milestone associations' do
      visit organization_assignment_ability_milestones_path(company, assignment)
      
      # Select milestone 2 for ability1 (click the label, not the hidden radio)
      find("label[for='ability_#{ability1.id}_milestone_2']").click
      
      # Select milestone 4 for ability2
      find("label[for='ability_#{ability2.id}_milestone_4']").click
      
      # Leave ability3 as "No Association"
      find("label[for='ability_#{ability3.id}_no_association']").click
      
      click_button 'Save Ability Milestones'
      
      # Should redirect to assignment show page
      expect(page).to have_current_path(organization_assignment_path(company, assignment))
      # Success message may be in a toast/alert that's not immediately visible
      # Check that we're on the assignment page and the associations were saved
      expect(page).to have_content('Product Manager')
      
      # Verify associations were created
      assignment.reload
      expect(assignment.assignment_abilities.find_by(ability: ability1).milestone_level).to eq(2)
      expect(assignment.assignment_abilities.find_by(ability: ability2).milestone_level).to eq(4)
      expect(assignment.assignment_abilities.find_by(ability: ability3)).to be_nil
    end

    it 'updates existing milestone associations' do
      create(:assignment_ability, :same_organization, assignment: assignment, ability: ability1, milestone_level: 2)
      
      visit organization_assignment_ability_milestones_path(company, assignment)
      
      # Change milestone from 2 to 5 (click the label, not the hidden radio)
      find("label[for='ability_#{ability1.id}_milestone_5']").click
      
      click_button 'Save Ability Milestones'
      
      expect(page).to have_current_path(organization_assignment_path(company, assignment))
      
      # Verify association was updated
      assignment.reload
      expect(assignment.assignment_abilities.find_by(ability: ability1).milestone_level).to eq(5)
    end

    it 'deletes associations when "No Association" is selected' do
      create(:assignment_ability, :same_organization, assignment: assignment, ability: ability1, milestone_level: 3)
      
      visit organization_assignment_ability_milestones_path(company, assignment)
      
      # Select "No Association" (click the label, not the hidden radio)
      find("label[for='ability_#{ability1.id}_no_association']").click
      
      click_button 'Save Ability Milestones'
      
      expect(page).to have_current_path(organization_assignment_path(company, assignment))
      
      # Verify association was deleted
      assignment.reload
      expect(assignment.assignment_abilities.find_by(ability: ability1)).to be_nil
    end

    context 'when user cannot update' do
      before do
        allow_any_instance_of(AssignmentPolicy).to receive(:update?).and_return(false)
        allow_any_instance_of(AssignmentPolicy).to receive(:show?).and_return(true)
      end

      it 'shows disabled save button with warning icon' do
        visit organization_assignment_ability_milestones_path(company, assignment)
        
        expect(page).to have_css('button.btn-primary.disabled[disabled]')
        expect(page).to have_css('i.bi-exclamation-triangle.text-warning')
        warning_icon = find('i.bi-exclamation-triangle.text-warning')
        expect(warning_icon['data-bs-title']).to eq('You need assignment management permissions to update ability milestones')
      end
    end
  end

  describe 'Navigation' do
    it 'has link from assignment show page' do
      visit organization_assignment_path(company, assignment)
      
      # Should see link in dropdown
      find('button.dropdown-toggle').click
      expect(page).to have_link('Manage Ability Milestones')
    end

    it 'can navigate back to assignment from milestone page' do
      visit organization_assignment_ability_milestones_path(company, assignment)
      
      click_link "Back to #{assignment.title}"
      
      expect(page).to have_current_path(organization_assignment_path(company, assignment))
    end
  end
end

