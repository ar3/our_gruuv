require 'rails_helper'

RSpec.describe 'Observation Creation Wizard', type: :feature do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee1) { create(:teammate, organization: company) }
  let(:observee2) { create(:teammate, organization: company) }
  let(:ability) { create(:ability, organization: company) }
  let(:assignment) { create(:assignment, company: company) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(observer)
    observer_teammate # Ensure observer teammate is created
  end

  describe 'Step 1: Basic form functionality' do
    it 'renders and submits Step 1 form correctly' do
      visit new_organization_observation_path(company)
      
      # Fill out Step 1 form
      fill_in 'observation[story]', with: 'Great work on the project!'
      select 'Happy', from: 'observation[primary_feeling]'
      select 'Proud', from: 'observation[secondary_feeling]'
      fill_in 'observation[observed_at]', with: Date.current.strftime('%Y-%m-%dT%H:%M')
      
      # Select observees (use the first available teammate)
      first_teammate_checkbox = page.find('input[name="observation[teammate_ids][]"]', match: :first)
      first_teammate_checkbox.check
      
      # Submit Step 1
      find('input[type="submit"][value="2"]').click
      
      # Should redirect to Step 2 (even if session data is lost, the redirect should work)
      expect(page).to have_current_path(set_ratings_organization_observation_path(company, 'new'))
    end

    it 'handles validation errors gracefully' do
      # Step 1: Submit invalid data
      visit new_organization_observation_path(company)
      
      # Submit without required fields
      find('input[type="submit"][value="2"]').click
      
      # Should stay on Step 1 with errors
      expect(page).to have_current_path(organization_observations_path(company))
      expect(page).to have_content("can't be blank")
    end

    it 'preserves form data on validation errors' do
      # Step 1: Fill out some fields but miss required ones
      visit new_organization_observation_path(company)
      
      fill_in 'observation[story]', with: 'Test story'
      select 'Happy', from: 'observation[primary_feeling]'
      page.find('input[name="observation[teammate_ids][]"]', match: :first).check
      
      # Submit with missing required field
      find('input[type="submit"][value="2"]').click
      
      # Should preserve the filled data
      expect(page).to have_field('observation[story]', with: 'Test story')
      expect(page).to have_select('observation[primary_feeling]', selected: '😀 (Happy) Happy')
      expect(page).to have_checked_field(page.find('input[name="observation[teammate_ids][]"]', match: :first)['id'])
    end
  end

  describe 'Individual wizard steps' do
    it 'renders Step 1 form correctly' do
      visit new_organization_observation_path(company)
      
      expect(page).to have_content('Create Observation')
      expect(page).to have_field('observation[story]')
      expect(page).to have_select('observation[primary_feeling]')
      expect(page).to have_select('observation[secondary_feeling]')
      expect(page).to have_field('observation[observed_at]')
      expect(page).to have_css('input[type="submit"][value="2"]')
    end
  end
end