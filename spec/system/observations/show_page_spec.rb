require 'rails_helper'

RSpec.describe 'Observation Show Page', type: :system do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let!(:observer_teammate) { CompanyTeammate.create!(person: observer, organization: company) }
  let(:observee_person) { create(:person) }
  let!(:observee_teammate) { CompanyTeammate.create!(person: observee_person, organization: company) }
  let(:other_person) { create(:person) }
  let!(:other_teammate) { CompanyTeammate.create!(person: other_person, organization: company) }

  before do
    sign_in_as(observer, company)
  end

  describe 'Publish button' do
    context 'when observation is a draft' do
      let(:draft_observation) do
        build(:observation, observer: observer, company: company, published_at: nil, story: 'Test story').tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
        end
      end

      it 'shows publish button for observer' do
        visit organization_observation_path(company, draft_observation)
        expect(page).to have_button('Publish')
      end

      it 'publishes observation when clicked' do
        visit organization_observation_path(company, draft_observation)
        click_button 'Publish'
        
        draft_observation.reload
        expect(draft_observation.published_at).to be_present
        expect(page).to have_current_path(organization_observation_path(company, draft_observation))
        expect(page).to have_content('Observation was successfully published')
      end

      it 'does not allow non-observer to access show page' do
        switch_to_user(observee_person, company)
        # Non-observers are not authorized to view the show page
        # The controller redirects to kudos path, which then redirects with flash message
        visit organization_observation_path(company, draft_observation)
        
        # Should be redirected (likely to dashboard for authenticated users)
        expect(page.current_path).not_to eq(organization_observation_path(company, draft_observation))
        # Should see authorization error message
        expect(page).to have_content(/not authorized|You are not authorized/i)
      end
    end

    context 'when observation is already published' do
      let(:published_observation) do
        build(:observation, observer: observer, company: company, story: 'Test story').tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          obs.publish!
        end
      end

      it 'does not show publish button' do
        visit organization_observation_path(company, published_observation)
        expect(page).not_to have_button('Publish')
      end
    end

    context 'when observation is published (cannot publish)' do
      let(:published_observation) do
        build(:observation, observer: observer, company: company, story: 'Test story').tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          obs.publish!
        end
      end

      it 'does not show publish button for published observation' do
        visit organization_observation_path(company, published_observation)
        expect(page).not_to have_button('Publish')
      end
    end
  end
end

