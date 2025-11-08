require 'rails_helper'

RSpec.describe 'Abilities with Milestones', type: :system do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: organization, can_manage_employment: true, can_manage_maap: true) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(person).to receive(:can_manage_employment?).and_return(true)
    allow(person).to receive(:can_manage_maap?).and_return(true)
  end

  describe 'Ability creation with milestones' do
    it 'loads new ability form' do
      visit new_organization_ability_path(organization)
      
      # Should see the form
      expect(page).to have_content('New Ability')
      expect(page).to have_field('ability_name')
      expect(page).to have_field('ability_description')
      expect(page).to have_field('ability_organization_id')
      
      # Should see milestone descriptions section
      expect(page).to have_content('Milestone Descriptions')
      expect(page).to have_field('ability_milestone_1_description')
      expect(page).to have_field('ability_milestone_2_description')
      expect(page).to have_field('ability_milestone_3_description')
      expect(page).to have_field('ability_milestone_4_description')
      expect(page).to have_field('ability_milestone_5_description')
      
      # Should see version section
      expect(page).to have_content('Ready for Use')
      expect(page).to have_content('Nearly Ready')
      expect(page).to have_content('Early Draft')
      
      # Should see create button
      expect(page).to have_button('Create Ability')
    end

    it 'creates ability with milestones' do
      visit new_organization_ability_path(organization)
      
      # Fill out the form
      fill_in 'ability_name', with: 'Ruby Programming'
      fill_in 'ability_description', with: 'Ability to write, debug, and maintain Ruby applications'
      fill_in 'ability_milestone_1_description', with: 'Can write basic Ruby scripts and understand syntax'
      fill_in 'ability_milestone_2_description', with: 'Can write object-oriented Ruby code and use common gems'
      fill_in 'ability_milestone_3_description', with: 'Can build Rails applications and understand MVC patterns'
      fill_in 'ability_milestone_4_description', with: 'Can architect complex Ruby applications and mentor others'
      fill_in 'ability_milestone_5_description', with: 'Can contribute to Ruby language development and lead technical decisions'
      
      # Select version type
      choose 'version_type_ready'
      
      click_button 'Create Ability'
      
      # Should redirect to show page
      expect(page).to have_content('Ruby Programming')
      expect(page).to have_content('Ability to write, debug, and maintain Ruby applications')
      
      # Should see milestone descriptions
      expect(page).to have_content('Milestone Descriptions')
      expect(page).to have_content('Milestone 1')
      expect(page).to have_content('Can write basic Ruby scripts and understand syntax')
      expect(page).to have_content('Milestone 2')
      expect(page).to have_content('Can write object-oriented Ruby code and use common gems')
      
      # Verify in database
      ability = Ability.last
      expect(ability.name).to eq('Ruby Programming')
      expect(ability.description).to eq('Ability to write, debug, and maintain Ruby applications')
      expect(ability.milestone_1_description).to eq('Can write basic Ruby scripts and understand syntax')
      expect(ability.milestone_2_description).to eq('Can write object-oriented Ruby code and use common gems')
      expect(ability.organization.id).to eq(organization.id)
    end

    it 'shows validation errors for missing required fields' do
      visit new_organization_ability_path(organization)
      
      # Try to submit empty form
      click_button 'Create Ability'
      
      # Should stay on form (validation prevents submission)
      expect(page).to have_content('New Ability')
    end
  end

  describe 'Ability editing with milestones' do
    let!(:ability) do
      create(:ability,
        organization: organization,
        name: 'JavaScript Programming',
        description: 'Ability to write JavaScript applications',
        milestone_1_description: 'Can write basic JavaScript',
        milestone_2_description: 'Can use modern JavaScript features',
        milestone_3_description: 'Can build complex applications',
        created_by: person,
        updated_by: person
      )
    end

    it 'loads ability show page with milestones' do
      visit organization_ability_path(organization, ability)
      
      # Should see ability show page
      expect(page).to have_content('JavaScript Programming')
      expect(page).to have_content('Ability to write JavaScript applications')
      expect(page).to have_content('Ability Details')
      expect(page).to have_content('Milestone Descriptions')
      
      # Should see milestone descriptions
      expect(page).to have_content('Milestone 1')
      expect(page).to have_content('Can write basic JavaScript')
      expect(page).to have_content('Milestone 2')
      expect(page).to have_content('Can use modern JavaScript features')
      expect(page).to have_content('Milestone 3')
      expect(page).to have_content('Can build complex applications')
      
      # Should see analytics
      expect(page).to have_content('Spotlight')
      expect(page).to have_content('Analytics')
      expect(page).to have_content('People with milestones:')
    end

    it 'loads edit form with pre-populated data' do
      visit edit_organization_ability_path(organization, ability)
      
      # Should see edit form
      expect(page).to have_content('Edit JavaScript Programming')
      expect(page).to have_field('ability_name', with: 'JavaScript Programming')
      expect(page).to have_field('ability_description', with: 'Ability to write JavaScript applications')
      expect(page).to have_field('ability_milestone_1_description', with: 'Can write basic JavaScript')
      expect(page).to have_field('ability_milestone_2_description', with: 'Can use modern JavaScript features')
      
      # Should see update button
      expect(page).to have_button('Update Ability')
    end

    it 'updates ability with new milestones' do
      visit edit_organization_ability_path(organization, ability)
      
      # Should see edit form
      expect(page).to have_content('Edit JavaScript Programming')
      
      # Update the form
      fill_in 'ability_name', with: 'Advanced JavaScript Programming'
      fill_in 'ability_description', with: 'Advanced ability to write complex JavaScript applications'
      fill_in 'ability_milestone_4_description', with: 'Can architect large-scale JavaScript applications'
      fill_in 'ability_milestone_5_description', with: 'Can contribute to JavaScript ecosystem and lead technical decisions'
      
      # Select version type (required for updates)
      choose 'version_type_clarifying'
      
      click_button 'Update Ability'
      
      # Should redirect to show page
      expect(page).to have_content('Advanced JavaScript Programming')
      expect(page).to have_content('Advanced ability to write complex JavaScript applications')
      expect(page).to have_content('Can architect large-scale JavaScript applications')
      expect(page).to have_content('Can contribute to JavaScript ecosystem and lead technical decisions')
      
      # Verify updates in database
      ability.reload
      expect(ability.name).to eq('Advanced JavaScript Programming')
      expect(ability.description).to eq('Advanced ability to write complex JavaScript applications')
      expect(ability.milestone_4_description).to eq('Can architect large-scale JavaScript applications')
      expect(ability.milestone_5_description).to eq('Can contribute to JavaScript ecosystem and lead technical decisions')
    end
  end

  describe 'Ability milestone analytics' do
    let!(:ability) do
      create(:ability,
        organization: organization,
        name: 'Project Management',
        description: 'Ability to manage projects effectively',
        milestone_1_description: 'Can manage small projects',
        milestone_2_description: 'Can manage medium projects',
        milestone_3_description: 'Can manage large projects',
        created_by: person,
        updated_by: person
      )
    end
    let!(:employee1) { create(:person, full_name: 'John Doe', email: 'john@example.com') }
    let!(:employee2) { create(:person, full_name: 'Jane Smith', email: 'jane@example.com') }
    let!(:employee1_teammate) { create(:teammate, person: employee1, organization: organization) }
    let!(:employee2_teammate) { create(:teammate, person: employee2, organization: organization) }

    it 'shows ability without milestone attainments' do
      visit organization_ability_path(organization, ability)
      
      # Should see ability details
      expect(page).to have_content('Project Management')
      expect(page).to have_content('Ability to manage projects effectively')
      
      # Should see analytics
      expect(page).to have_content('People with milestones:')
      expect(page).to have_content('0')
      expect(page).to have_content('people')
      expect(page).to have_content('No milestone attainments yet')
    end

    it 'shows ability with milestone attainments' do
      # Create milestone attainments
      create(:teammate_milestone,
        teammate: employee1_teammate,
        ability: ability,
        milestone_level: 2,
        certified_by: person,
        attained_at: Date.current
      )
      create(:teammate_milestone,
        teammate: employee2_teammate,
        ability: ability,
        milestone_level: 3,
        certified_by: person,
        attained_at: Date.current
      )
      
      visit organization_ability_path(organization, ability)
      
      # Should see ability details
      expect(page).to have_content('Project Management')
      expect(page).to have_content('Ability to manage projects effectively')
      
      # Should see analytics with milestone data
      expect(page).to have_content('People with milestones:')
      expect(page).to have_content('2')
      expect(page).to have_content('people')
      expect(page).to have_content('2 persons have milestones')
    end
  end

  describe 'Navigation and UI elements' do
    it 'navigates between ability pages' do
      # Start at abilities index
      visit organization_abilities_path(organization)
      
      # Should see abilities index
      expect(page).to have_content('Abilities')
      expect(page).to have_content('Total Abilities')
      expect(page).to have_content('With Milestones')
      
      # Navigate to new ability (plus button)
      find('a.btn.btn-primary i.bi-plus').click
      expect(page).to have_content('New Ability')
      
      # Navigate back to index
      click_link 'Back to Abilities'
      expect(page).to have_content('Abilities')
    end

    it 'shows ability in index after creation' do
      ability = create(:ability, 
        organization: organization, 
        name: 'Database Design',
        description: 'Ability to design and optimize databases',
        created_by: person,
        updated_by: person
      )
      
      visit organization_abilities_path(organization)
      
      # Should see the ability
      expect(page).to have_content('Database Design')
      expect(page).to have_content('Ability to design and optimize databases')
      expect(page).to have_content('1.0.0') # default version
    end

    it 'shows empty state when no abilities exist' do
      visit organization_abilities_path(organization)
      
      # Should see empty state
      expect(page).to have_content('No Abilities Created')
      expect(page).to have_content('Create your first ability to define competencies and skills for your team')
      expect(page).to have_link('Create First Ability')
    end

    it 'shows ability spotlight and analytics' do
      ability = create(:ability, 
        organization: organization, 
        name: 'Leadership',
        description: 'Ability to lead teams effectively',
        created_by: person,
        updated_by: person
      )
      
      visit organization_abilities_path(organization)
      
      # Should see spotlight section
      expect(page).to have_content('Total Abilities')
      expect(page).to have_content('With Milestones')
      expect(page).to have_content('Recent (30 days)')
      expect(page).to have_content('Active Abilities')
      expect(page).to have_content('Top Abilities by Milestones')
    end
  end
end
