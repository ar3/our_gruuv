require 'rails_helper'

RSpec.describe 'Archive and Restore Observations', type: :system do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let!(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee_person) { create(:person) }
  let!(:observee_teammate) { create(:teammate, person: observee_person, organization: company) }
  let(:observation) do
    obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_world, story: 'Normal observation story')
    obs.observees.build(teammate: observee_teammate)
    obs.save!
    obs.publish!
    obs
  end

  before do
    sign_in_as(observer, company)
  end

  # Archive/restore behavior (status, redirect, DB) is covered by
  # spec/requests/organizations/observations_spec.rb. This keeps minimal UX smoke for show page.
  describe 'Archive from show page' do
    it 'allows observer to archive observation', js: true do
      visit organization_observation_path(company, observation)
      expect(page).to have_button('Archive')

      click_button 'Archive'

      expect(page).to have_current_path(organization_observation_path(company, observation), wait: 5)
      expect(page).to have_content('Observation was successfully archived.')
      expect(page).to have_button('Restore')
      expect(observation.reload.soft_deleted?).to be true
    end

    it 'allows observer to restore archived observation' do
      observation.soft_delete!
      visit organization_observation_path(company, observation)
      expect(page).to have_button('Restore')

      click_button 'Restore'

      expect(page).to have_current_path(organization_observation_path(company, observation))
      expect(page).to have_content('Observation was successfully restored.')
      expect(observation.reload.soft_deleted?).to be false
    end
  end

  describe 'Index page filtering' do
    let!(:soft_deleted_observation) do
      obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_world, story: 'Soft deleted observation story')
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs.publish!
      obs.soft_delete!
      obs
    end

    it 'excludes soft-deleted observations by default' do
      # Ensure observations are set up correctly
      expect(observation.reload).to be_present
      expect(soft_deleted_observation.reload).to be_present
      expect(observation.soft_deleted?).to be false
      expect(soft_deleted_observation.soft_deleted?).to be true
      
      visit organization_observations_path(company)
      
      # Should see the normal observation (observer can see their own published observations)
      expect(page).to have_content('Normal observation story')
      # Should NOT see the soft-deleted observation
      expect(page).not_to have_content('Soft deleted observation story')
    end

    it 'includes soft-deleted observations when filter is enabled' do
      # Ensure observations are set up correctly
      expect(observation.reload).to be_present
      expect(soft_deleted_observation.reload).to be_present
      
      visit organization_observations_path(company, include_soft_deleted: 'true')
      
      # Should see both observations when filter is enabled
      expect(page).to have_content('Normal observation story')
      # The soft-deleted observation should be visible to the observer when filter is enabled
      expect(page).to have_content('Soft deleted observation story')
    end
  end

  describe 'Public permalink blocking' do
    before do
      observation.update!(privacy_level: :public_to_world)
      observation.soft_delete!
    end

    it 'blocks access to soft-deleted observation via public permalink' do
      date_part = observation.observed_at.strftime('%Y-%m-%d')
      visit organization_kudo_path(company, date: date_part, id: observation.id)
      
      # The kudos controller redirects to root_path with an alert
      # But if user is signed in, it might redirect to dashboard
      expect(page).to have_content('You are not authorized to view this observation')
      # The important part is that access is denied, not the exact redirect path
    end
  end

  describe 'Visibility restrictions' do
    let(:other_person) { create(:person) }
    let!(:other_teammate) { create(:teammate, person: other_person, organization: company) }

    before do
      observation.soft_delete!
    end

    it 'allows observer to see their archived observation' do
      visit organization_observation_path(company, observation)
      
      expect(page).to have_content(observation.story)
      expect(page).to have_button('Restore')
    end

    it 'denies non-observer from seeing archived observation' do
      sign_in_as(other_person, company)
      
      visit organization_observation_path(company, observation)
      
      # Should redirect or show unauthorized
      expect(page).not_to have_content(observation.story)
    end
  end
end

