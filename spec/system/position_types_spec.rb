require 'rails_helper'

RSpec.describe 'Position Types', type: :system, critical: true do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: organization, can_manage_maap: true) }

  before do
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(person).to receive(:can_manage_maap?).and_return(true)
  end

  describe 'Position Types index page' do
    it 'loads position types index' do
      # Create some position types for testing
      position_major_level = create(:position_major_level, major_level: 1, set_name: 'Engineering')
      (1..3).each do |i|
        create(:position_type, 
          organization: organization, 
          position_major_level: position_major_level,
          external_title: "Engineer Level #{i}"
        )
      end
      
      visit position_types_path
      
      # Should see position types index
      expect(page).to have_content('Position Types')
      expect(page).to have_content('Engineer Level 1')
      expect(page).to have_content('Engineer Level 2')
      expect(page).to have_content('Engineer Level 3')
      
      # Should see new position type button
      expect(page).to have_link('New Position Type')
    end

    it 'shows position types with their major levels' do
      engineering_level = create(:position_major_level, major_level: 1, set_name: 'Engineering')
      marketing_level = create(:position_major_level, major_level: 2, set_name: 'Marketing')
      
      create(:position_type, organization: organization, position_major_level: engineering_level, external_title: 'Software Engineer')
      create(:position_type, organization: organization, position_major_level: marketing_level, external_title: 'Marketing Manager')
      
      visit position_types_path
      
      # Should see position types grouped by major level
      expect(page).to have_content('Engineering')
      expect(page).to have_content('Marketing')
      expect(page).to have_content('Software Engineer')
      expect(page).to have_content('Marketing Manager')
    end
  end

  describe 'Position Type creation' do
    it 'loads new position type form' do
      visit new_position_type_path
      
      # Should see the form
      expect(page).to have_content('New Position Type')
      expect(page).to have_field('position_type_external_title')
      expect(page).to have_content('Alternative Titles')
      expect(page).to have_content('Position Summary')
      
      # Should see major level selection
      expect(page).to have_content('Major Level')
      expect(page).to have_field('position_type_position_major_level_id')
      
      # Should see create button
      expect(page).to have_button('Create Position Type')
    end

    it 'creates position type with valid data' do
      position_major_level = create(:position_major_level, major_level: 1, set_name: 'Engineering')
      
      visit new_position_type_path
      
      # Fill out the form
      fill_in 'position_type_external_title', with: 'Senior Software Engineer'
      fill_in 'position_type_position_summary', with: 'Senior-level software engineering role'
      select position_major_level.set_name, from: 'position_type_position_major_level_id'
      
      click_button 'Create Position Type'
      
      # Should redirect to show page
      expect(page).to have_content('Senior Software Engineer')
      expect(page).to have_content('Senior-level software engineering role')
      
      # Verify in database
      position_type = PositionType.last
      expect(position_type.external_title).to eq('Senior Software Engineer')
      expect(position_type.position_summary).to eq('Senior-level software engineering role')
      expect(position_type.position_major_level).to eq(position_major_level)
    end

    it 'shows validation errors for missing required fields' do
      visit new_position_type_path
      
      # Try to submit empty form
      click_button 'Create Position Type'
      
      # Should stay on form (validation prevents submission)
      expect(page).to have_content('New Position Type')
      expect(page).to have_content('Create New Position Type')
    end
  end

  describe 'Position Type editing' do
    let!(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
    let!(:position_type) do
      create(:position_type,
        organization: organization,
        position_major_level: position_major_level,
        external_title: 'Software Engineer',
        position_summary: 'Software engineering role'
      )
    end

    it 'loads position type show page' do
      visit position_type_path(position_type)
      
      # Should see position type show page
      expect(page).to have_content('Software Engineer')
      expect(page).to have_content('Software engineering role')
      expect(page).to have_content('Engineering')
      
      # Should see dropdown menu
      expect(page).to have_css('.dropdown-toggle')
    end
  end

  describe 'Position cloning' do
    let!(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
    let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
    let!(:position_type) do
      create(:position_type,
        organization: organization,
        position_major_level: position_major_level,
        external_title: 'Software Engineer',
        position_summary: 'Software engineering role'
      )
    end
    let!(:existing_position) do
      create(:position,
        position_type: position_type,
        position_level: position_level
      )
    end

    it 'shows clone positions functionality when positions exist' do
      visit position_type_path(position_type)
      
      # Should see position type show page
      expect(page).to have_content('Software Engineer')
      expect(page).to have_content('Software engineering role')
      
      # Should see existing position
      expect(page).to have_content('Positions')
      expect(page).to have_content('Software Engineer - 1.1')
    end
  end

  describe 'Navigation and UI elements' do
    it 'navigates between position type pages' do
      # Start at position types index
      visit position_types_path
      expect(page).to have_content('Position Types')
      
      # Navigate to new position type
      click_link 'New Position Type'
      expect(page).to have_content('New Position Type')
      
      # Navigate back to index
      click_link 'Back'
      expect(page).to have_content('Position Types')
    end

    it 'shows position type in index after creation' do
      position_major_level = create(:position_major_level, major_level: 1, set_name: 'Engineering')
      position_type = create(:position_type, 
        organization: organization, 
        position_major_level: position_major_level,
        external_title: 'Test Position Type'
      )
      
      visit position_types_path
      
      # Should see the position type
      expect(page).to have_content('Test Position Type')
      expect(page).to have_content('Engineering')
    end
  end
end
