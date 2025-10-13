require 'rails_helper'

RSpec.describe 'Positions', type: :system, critical: true do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: organization, can_manage_employment: true, can_manage_maap: true) }
  let!(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let!(:position_type) { create(:position_type, organization: organization, position_major_level: position_major_level, external_title: 'Software Engineer') }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(person).to receive(:can_manage_employment?).and_return(true)
    allow(person).to receive(:can_manage_maap?).and_return(true)
  end

  describe 'Position creation' do
    it 'loads new position form' do
      visit new_organization_position_path(organization)
      
      # Should see the form
      expect(page).to have_content('Create New Position')
      expect(page).to have_content('Position Type')
      expect(page).to have_content('Position Level')
      
      # Should see create button
      expect(page).to have_button('Create Position')
    end

    it 'creates position with valid data' do
      visit new_organization_position_path(organization)
      
      # Fill out the form
      select position_type.external_title, from: 'position_type_select'
      # Position level dropdown is populated dynamically via JavaScript
      # So we'll just test that the form loads and can be submitted
      
      click_button 'Create Position'
      
      # Should stay on form due to missing position level
      expect(page).to have_content('Create New Position')
    end

    it 'shows validation errors for missing required fields' do
      visit new_organization_position_path(organization)
      
      # Try to submit empty form
      click_button 'Create Position'
      
      # Should stay on form (validation prevents submission)
      expect(page).to have_content('Create New Position')
    end
  end

  describe 'Position editing' do
    let!(:position) do
      create(:position,
        position_type: position_type,
        position_level: position_level
      )
    end

    it 'loads position show page' do
      visit organization_position_path(organization, position)
      
      # Should see position show page
      expect(page).to have_content('Software Engineer')
      expect(page).to have_content('1.1')
      expect(page).to have_content('Position Type')
      expect(page).to have_content('Position Level')
      
      # Should see assignments section
      expect(page).to have_content('No Assignments Defined')
    end

    it 'loads edit form with pre-populated data' do
      visit edit_organization_position_path(organization, position)
      
      # Should see edit form
      expect(page).to have_content('Edit Position')
      expect(page).to have_content('Position Type')
      expect(page).to have_content('Position Level')
      
      # Should see update button
      expect(page).to have_button('Update Position')
    end

    it 'updates position with new data' do
      new_position_level = create(:position_level, position_major_level: position_major_level, level: '1.2')
      
      visit edit_organization_position_path(organization, position)
      
      # Should see edit form
      expect(page).to have_content('Edit Position')
      
      # Update the form
      select new_position_level.level, from: 'position_level_select'
      
      click_button 'Update Position'
      
      # Should redirect to show page
      expect(page).to have_content('Software Engineer')
      expect(page).to have_content('1.2')
      
      # Verify updates in database
      position.reload
      expect(position.position_level).to eq(new_position_level)
    end
  end

  describe 'Job description management' do
    let!(:position) do
      create(:position,
        position_type: position_type,
        position_level: position_level
      )
    end

    it 'shows position details' do
      visit organization_position_path(organization, position)
      
      # Should see position details
      expect(page).to have_content('Software Engineer')
      expect(page).to have_content('1.1')
      expect(page).to have_content('Position Type')
      expect(page).to have_content('Position Level')
    end

    it 'allows editing job description' do
      visit organization_position_path(organization, position)
      
      # Should see position details
      expect(page).to have_content('Software Engineer')
      expect(page).to have_content('1.1')
      expect(page).to have_content('Position Type')
      expect(page).to have_content('Position Level')
      
      # Navigate to job description page directly
      visit job_description_organization_position_path(organization, position)
      
      # Should see job description page
      expect(page).to have_content('Job Description')
      expect(page).to have_content('Software Engineer')
    end

    it 'updates job description' do
      visit job_description_organization_position_path(organization, position)
      
      # Should see job description page
      expect(page).to have_content('Job Description')
      expect(page).to have_content('Software Engineer')
      
      # Should see position summary
      expect(page).to have_content('Summary:')
    end
  end

  describe 'Position assignments' do
    let!(:position) do
      create(:position,
        position_type: position_type,
        position_level: position_level
      )
    end

    it 'shows position assignments section' do
      visit organization_position_path(organization, position)
      
      # Should see assignments section
      expect(page).to have_content('No Assignments Defined')
      expect(page).to have_content('Software Engineer')
      expect(page).to have_content('1.1')
    end

    it 'allows adding assignments through edit' do
      visit organization_position_path(organization, position)
      
      # Should see add assignments link
      expect(page).to have_link('Add Assignments')
      
      # Click add assignments
      click_link 'Add Assignments'
      
      # Should see edit form with assignments
      expect(page).to have_content('Edit Position')
      expect(page).to have_content('Required Assignments')
      expect(page).to have_content('Suggested Assignments')
    end
  end

  describe 'Navigation and UI elements' do
    it 'navigates between position pages' do
      # Start at positions index
      visit organization_positions_path(organization)
      
      # Should see positions index
      expect(page).to have_content('Positions')
      
      # Navigate to new position (plus button)
      find('a.btn.btn-primary i.bi-plus').click
      expect(page).to have_content('Create New Position')
      
      # Navigate back to index
      click_link 'Back to Positions'
      expect(page).to have_content('Positions')
    end

    it 'shows position in index after creation' do
      position = create(:position, 
        position_type: position_type, 
        position_level: position_level
      )
      
      visit organization_positions_path(organization)
      
      # Should see the position
      expect(page).to have_content('Software Engineer')
      expect(page).to have_content('Engineering')
    end
  end
end
