require 'rails_helper'

RSpec.describe 'Observation Form', type: :system do
  let(:organization) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let!(:observer_teammate) { create(:teammate, person: observer, organization: organization) }
  let(:observee1) { create(:teammate, organization: organization) }
  let(:observee2) { create(:teammate, organization: organization) }
  let(:ability1) { create(:ability, organization: organization, name: 'Ruby Programming') }
  let(:ability2) { create(:ability, organization: organization, name: 'JavaScript Development') }

  before do
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(observer)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(observer).to receive(:can_manage_maap?).and_return(true)
  end

  describe 'Simple observation creation' do
    it 'loads the new observation form' do
      visit new_organization_observation_path(organization)
      
      # Should see the form
      expect(page).to have_content('Create Observation')
      expect(page).to have_content('Step 1 of 3')
      expect(page).to have_content('Who, When, What, How')
      expect(page).to have_content('Who are you observing?')
      expect(page).to have_content('What happened?')
      expect(page).to have_content('How did this make you feel?')
      
      # Should see form fields
      expect(page).to have_field('observation_story')
      expect(page).to have_field('observation_observed_at')
      expect(page).to have_content('Individuals')
      
      # Should see step navigation
      expect(page).to have_content('Step 2: Ratings & Privacy')
      expect(page).to have_content('Step 3: Review & Manage')
    end

    it 'shows validation errors for missing required fields' do
      visit new_organization_observation_path(organization)
      
      # Try to submit without story
      click_button '2'
      
      # Should stay on step 1 (validation prevents progression)
      expect(page).to have_content('Step 1 of 3')
      expect(page).to have_content('Who, When, What, How')
    end
  end

  describe 'Complex observation creation' do
    it 'shows all form elements and wizard steps' do
      visit new_organization_observation_path(organization)
      
      # Should be on step 1
      expect(page).to have_content('Step 1 of 3')
      expect(page).to have_content('Who, When, What, How')
      
      # Should see all form elements
      expect(page).to have_field('observation_story')
      expect(page).to have_field('observation_observed_at')
      expect(page).to have_content('Who are you observing?')
      expect(page).to have_content('What happened?')
      expect(page).to have_content('How did this make you feel?')
      
      # Should see step navigation
      expect(page).to have_content('Step 2: Ratings & Privacy')
      expect(page).to have_content('Step 3: Review & Manage')
      
      # Should see feelings dropdown
      expect(page).to have_content('Select a feeling...')
      expect(page).to have_content('Happy')
      expect(page).to have_content('Confident')
    end
  end

  describe 'Observation editing' do
    let!(:existing_observation) do
      create(:observation,
        story: 'Good work on the project',
        privacy_level: 'observer_only',
        company: organization,
        observer: observer,
        observed_at: 1.week.ago
      ).tap do |obs|
        obs.observees.create!(teammate: observee1)
      end
    end

    it 'loads edit form with pre-populated data' do
      visit edit_organization_observation_path(organization, existing_observation)
      
      # Should see pre-populated form
      expect(page).to have_field('observation_story', with: 'Good work on the project')
      expect(page).to have_content('Edit Observation')
      
      # Should see update button
      expect(page).to have_button('Update Observation')
    end
  end

  describe 'Navigation and UI elements' do
    it 'navigates to observations index and shows new observation button' do
      visit organization_observations_path(organization)
      
      # Should see observations index
      expect(page).to have_content('Observations')
      expect(page).to have_css('a.btn.btn-primary i.bi-plus')
      
      # Click new observation button (plus icon)
      find('a.btn.btn-primary i.bi-plus').click
      
      # Should be on new observation form
      expect(page).to have_current_path(new_organization_observation_path(organization))
      expect(page).to have_content('Create Observation')
    end

    it 'shows observations index page' do
      visit organization_observations_path(organization)
      
      # Should see observations index
      expect(page).to have_content('Observations')
      expect(page).to have_css('a.btn.btn-primary i.bi-plus')
    end
  end
end
