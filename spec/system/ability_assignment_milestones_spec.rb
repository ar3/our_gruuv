require 'rails_helper'

RSpec.describe 'Ability Assignment Milestones', type: :system, critical: true do
  let(:company) { create(:organization, :company) }
  let(:department) { create(:organization, :department, parent: company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: company, can_manage_maap: true) }
  let!(:ability) { create(:ability, organization: company, name: 'Ruby Programming') }
  let!(:assignment1) { create(:assignment, company: company, title: 'Product Manager') }
  let!(:assignment2) { create(:assignment, company: company, title: 'Engineering Lead') }
  let!(:assignment3) { create(:assignment, company: company, title: 'Design Lead') }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(company)
    allow(person).to receive(:can_manage_maap?).and_return(true)
    # Set up Pundit user context
    allow_any_instance_of(Organizations::Abilities::AssignmentMilestonesController).to receive(:pundit_user).and_return(
      OpenStruct.new(user: person, pundit_organization: company)
    )
    # Mock authorization
    allow_any_instance_of(AbilityPolicy).to receive(:show?).and_return(true)
    allow_any_instance_of(AbilityPolicy).to receive(:update?).and_return(true)
  end

  describe 'Ability-centric milestone management' do
    it 'loads the assignment milestones page with all assignments in hierarchy' do
      # Create assignment in department to test hierarchy scoping
      assignment_in_dept = create(:assignment, company: department, title: 'Department Assignment')
      
      visit organization_ability_assignment_milestones_path(company, ability)
      
      expect(page).to have_content('Ruby Programming - Assignment Milestones')
      expect(page).to have_content('Product Manager')
      expect(page).to have_content('Engineering Lead')
      expect(page).to have_content('Design Lead')
      expect(page).to have_content('Department Assignment')
      
      # Should see radio buttons for each assignment
      expect(page).to have_css("input[type='radio'][id='assignment_#{assignment1.id}_milestone_1']")
      expect(page).to have_css("input[type='radio'][id='assignment_#{assignment1.id}_milestone_5']")
      expect(page).to have_css("input[type='radio'][id='assignment_#{assignment1.id}_no_association']")
      
      # Should see save button
      expect(page).to have_button('Save Assignment Milestones')
    end

    it 'pre-selects existing milestone associations' do
      create(:assignment_ability, :same_organization, ability: ability, assignment: assignment1, milestone_level: 3)
      create(:assignment_ability, :same_organization, ability: ability, assignment: assignment2, milestone_level: 5)
      
      visit organization_ability_assignment_milestones_path(company, ability)
      
      # Should have milestone 3 selected for assignment1
      expect(page).to have_checked_field("assignment_#{assignment1.id}_milestone_3")
      
      # Should have milestone 5 selected for assignment2
      expect(page).to have_checked_field("assignment_#{assignment2.id}_milestone_5")
      
      # Should have no association selected for assignment3
      expect(page).to have_checked_field("assignment_#{assignment3.id}_no_association")
    end

    it 'creates new milestone associations' do
      visit organization_ability_assignment_milestones_path(company, ability)
      
      # Select milestone 2 for assignment1 (click the label, not the hidden radio)
      find("label[for='assignment_#{assignment1.id}_milestone_2']").click
      
      # Select milestone 4 for assignment2
      find("label[for='assignment_#{assignment2.id}_milestone_4']").click
      
      # Leave assignment3 as "No Association"
      find("label[for='assignment_#{assignment3.id}_no_association']").click
      
      click_button 'Save Assignment Milestones'
      
      # Should redirect to ability show page
      expect(page).to have_current_path(organization_ability_path(company, ability))
      expect(page).to have_content('Assignment milestone associations were successfully updated')
      
      # Verify associations were created
      ability.reload
      expect(ability.assignment_abilities.find_by(assignment: assignment1).milestone_level).to eq(2)
      expect(ability.assignment_abilities.find_by(assignment: assignment2).milestone_level).to eq(4)
      expect(ability.assignment_abilities.find_by(assignment: assignment3)).to be_nil
    end

    it 'updates existing milestone associations' do
      create(:assignment_ability, :same_organization, ability: ability, assignment: assignment1, milestone_level: 2)
      
      visit organization_ability_assignment_milestones_path(company, ability)
      
      # Change milestone from 2 to 5 (click the label, not the hidden radio)
      find("label[for='assignment_#{assignment1.id}_milestone_5']").click
      
      click_button 'Save Assignment Milestones'
      
      expect(page).to have_current_path(organization_ability_path(company, ability))
      
      # Verify association was updated
      ability.reload
      expect(ability.assignment_abilities.find_by(assignment: assignment1).milestone_level).to eq(5)
    end

    it 'deletes associations when "No Association" is selected' do
      create(:assignment_ability, :same_organization, ability: ability, assignment: assignment1, milestone_level: 3)
      
      visit organization_ability_assignment_milestones_path(company, ability)
      
      # Select "No Association" (click the label, not the hidden radio)
      find("label[for='assignment_#{assignment1.id}_no_association']").click
      
      click_button 'Save Assignment Milestones'
      
      expect(page).to have_current_path(organization_ability_path(company, ability))
      
      # Verify association was deleted
      ability.reload
      expect(ability.assignment_abilities.find_by(assignment: assignment1)).to be_nil
    end

    context 'when user cannot update' do
      before do
        allow_any_instance_of(AbilityPolicy).to receive(:update?).and_return(false)
        allow_any_instance_of(AbilityPolicy).to receive(:show?).and_return(true)
      end

      it 'shows disabled save button with warning icon' do
        visit organization_ability_assignment_milestones_path(company, ability)
        
        expect(page).to have_css('button.btn-primary.disabled[disabled]')
        expect(page).to have_css('i.bi-exclamation-triangle.text-warning')
        warning_icon = find('i.bi-exclamation-triangle.text-warning')
        expect(warning_icon['data-bs-title']).to eq('You need MAAP management permissions to update assignment milestones')
      end
    end
  end

  describe 'Navigation' do
    it 'has link from ability show page' do
      visit organization_ability_path(company, ability)
      
      # Should see link in spotlight actions
      expect(page).to have_link('Manage Assignment Milestones')
    end

    it 'can navigate back to ability from milestone page' do
      visit organization_ability_assignment_milestones_path(company, ability)
      
      click_link "Back to #{ability.name}"
      
      expect(page).to have_current_path(organization_ability_path(company, ability))
    end
  end
end

