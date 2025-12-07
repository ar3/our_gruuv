require 'rails_helper'

RSpec.describe 'Manage Observees', type: :system do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let!(:observer_teammate) { CompanyTeammate.create!(person: observer, organization: company) }
  let(:observee_person) { create(:person) }
  let!(:observee_teammate) { CompanyTeammate.create!(person: observee_person, organization: company) }
  let(:new_person) { create(:person) }
  let!(:new_teammate) { CompanyTeammate.create!(person: new_person, organization: company) }
  let(:another_person) { create(:person) }
  let!(:another_teammate) { CompanyTeammate.create!(person: another_person, organization: company) }

  before do
    sign_in_as(observer, company)
  end

  describe 'managing observees from new observation page' do
    let(:draft) do
      build(:observation, observer: observer, company: company, published_at: nil).tap do |obs|
        obs.observees.build(teammate: observee_teammate)
        obs.save!
      end
    end

    it 'navigates to manage observees from new observation page' do
      visit new_organization_observation_path(company, draft_id: draft.id)
      click_button 'Manage Observees'
      
      expect(page).to have_content('Manage Observees')
      expect(page).to have_content('Select Observees')
    end

    it 'shows all teammates with correct checked/unchecked state' do
      visit manage_observees_organization_observation_path(company, draft)
      
      # Existing observee should be checked
      checkbox = find("#teammate_#{observee_teammate.id}")
      expect(checkbox).to be_checked
      
      # Non-observees should be unchecked
      checkbox = find("#teammate_#{new_teammate.id}")
      expect(checkbox).not_to be_checked
      
      checkbox = find("#teammate_#{another_teammate.id}")
      expect(checkbox).not_to be_checked
    end

    it 'allows checking a new teammate to add them' do
      visit manage_observees_organization_observation_path(company, draft)
      
      # Check the new teammate
      check "teammate_#{new_teammate.id}"
      find('input[type="submit"][value="Save Changes"]', match: :first).click
      
      # Should show success message (regardless of redirect path)
      expect(page).to have_content('Added 1 observee(s)')
      
      # Verify the new observee was added
      draft.reload
      expect(draft.observees.pluck(:teammate_id)).to include(new_teammate.id)
    end

    it 'allows unchecking an existing observee to remove them' do
      visit manage_observees_organization_observation_path(company, draft)
      
      # Uncheck the existing observee
      uncheck "teammate_#{observee_teammate.id}"
      find('input[type="submit"][value="Save Changes"]', match: :first).click
      
      # Should show success message (regardless of redirect path)
      expect(page).to have_content('Removed 1 observee(s)')
      
      # Verify the observee was removed
      draft.reload
      expect(draft.observees.pluck(:teammate_id)).not_to include(observee_teammate.id)
    end

    it 'allows adding and removing in the same submission' do
      # Add another observee first
      draft.observees.create!(teammate: another_teammate)
      
      visit manage_observees_organization_observation_path(company, draft)
      
      # Uncheck one, check another
      uncheck "teammate_#{observee_teammate.id}"
      check "teammate_#{new_teammate.id}"
      find('input[type="submit"][value="Save Changes"]', match: :first).click
      
      # Should show success message (regardless of redirect path)
      expect(page).to have_content('Added 1 observee(s) and removed 1 observee(s)')
      
      # Verify changes - reload draft to get fresh data
      draft.reload
      observee_ids = draft.observees.pluck(:teammate_id)
      expect(observee_ids).not_to include(observee_teammate.id)
      expect(observee_ids).to include(new_teammate.id, another_teammate.id)
    end

    it 'shows success message after saving changes' do
      visit manage_observees_organization_observation_path(company, draft)
      
      check "teammate_#{new_teammate.id}"
      find('input[type="submit"][value="Save Changes"]', match: :first).click
      
      expect(page).to have_content('Added 1 observee(s)')
    end

    it 'redirects back to new observation page with return params' do
      visit manage_observees_organization_observation_path(
        company,
        draft,
        return_url: organization_observations_path(company),
        return_text: 'Back to Observations'
      )
      
      find('input[type="submit"][value="Save Changes"]', match: :first).click
      
      expect(page).to have_current_path(
        new_organization_observation_path(
          company,
          draft_id: draft.id,
          return_url: organization_observations_path(company),
          return_text: 'Back to Observations'
        )
      )
    end
  end
end

