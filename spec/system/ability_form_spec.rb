require 'rails_helper'

RSpec.describe 'Ability Form', type: :system, critical: true do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: organization, can_manage_maap: true) }

  before do
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(person).to receive(:can_manage_maap?).and_return(true)
  end

  describe 'Simple ability creation' do
    it 'loads the new ability form' do
      visit new_organization_ability_path(organization)
      
      # Should see the form
      expect(page).to have_content('New Ability')
      expect(page).to have_field('ability_name')
      expect(page).to have_field('ability_description')
      expect(page).to have_content('Ready for Use')
      expect(page).to have_content('Nearly Ready')
      expect(page).to have_content('Early Draft')
      
      # Should see milestone fields
      expect(page).to have_field('ability_milestone_1_description')
      expect(page).to have_field('ability_milestone_2_description')
      expect(page).to have_field('ability_milestone_3_description')
      expect(page).to have_field('ability_milestone_4_description')
      expect(page).to have_field('ability_milestone_5_description')
      
      # Should see create button
      expect(page).to have_button('Create Ability')
    end

    it 'shows validation errors for missing required fields' do
      visit new_organization_ability_path(organization)
      
      # Try to submit empty form
      click_button 'Create Ability'
      
      # Should show validation errors
      expect(page).to have_content('Name can\'t be blank')
      expect(page).to have_content('Description can\'t be blank')
      expect(page).to have_content('At least one milestone description is required')
      
      # Should stay on form
      expect(page).to have_content('New Ability')
    end
  end

  describe 'Complex ability editing' do
    let!(:existing_ability) do
      create(:ability, 
        organization: organization,
        name: 'JavaScript Development',
        description: 'Frontend JavaScript skills',
        semantic_version: '1.0.0',
        milestone_1_description: 'Basic JavaScript',
        milestone_2_description: 'DOM manipulation',
        milestone_3_description: 'Async programming',
        milestone_4_description: 'Framework knowledge',
        milestone_5_description: 'Advanced patterns'
      )
    end

    it 'loads the edit ability form with pre-populated data' do
      visit edit_organization_ability_path(organization, existing_ability)
      
      # Should see pre-populated form
      expect(page).to have_field('ability_name', with: 'JavaScript Development')
      expect(page).to have_field('ability_description', with: 'Frontend JavaScript skills')
      expect(page).to have_field('ability_milestone_1_description', with: 'Basic JavaScript')
      expect(page).to have_field('ability_milestone_2_description', with: 'DOM manipulation')
      expect(page).to have_field('ability_milestone_3_description', with: 'Async programming')
      expect(page).to have_field('ability_milestone_4_description', with: 'Framework knowledge')
      expect(page).to have_field('ability_milestone_5_description', with: 'Advanced patterns')
      
      # Should see version options for editing
      expect(page).to have_content('Fundamental Change')
      expect(page).to have_content('Clarifying Change')
      expect(page).to have_content('Insignificant Change')
      expect(page).to have_content('Current version: 1.0.0')
      
      # Should see update button
      expect(page).to have_button('Update Ability')
    end
  end

  describe 'Navigation and UI elements' do
    it 'navigates to abilities index and shows new ability button' do
      visit organization_abilities_path(organization)
      
      # Should see abilities index
      expect(page).to have_content('Abilities')
      expect(page).to have_css('a.btn.btn-primary i.bi-plus')
      
      # Click new ability button (plus icon)
      find('a.btn.btn-primary i.bi-plus').click
      
      # Should be on new ability form
      expect(page).to have_current_path(new_organization_ability_path(organization))
      expect(page).to have_content('New Ability')
    end

    it 'shows ability in index after creation' do
      ability = create(:ability, organization: organization, name: 'Test Ability')
      
      visit organization_abilities_path(organization)
      
      # Should see the ability
      expect(page).to have_content('Test Ability')
      expect(page).to have_link('Test Ability', href: organization_ability_path(organization, ability))
    end
  end
end
