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

  describe 'GIFs section' do
    let(:observation_with_gifs) do
      build(:observation, observer: observer, company: company, story: 'Test story', story_extras: { 'gif_urls' => ['https://example.com/gif1.gif', 'https://example.com/gif2.gif'] }).tap do |obs|
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs.publish!
      end
    end

    let(:observation_without_gifs) do
      build(:observation, observer: observer, company: company, story: 'Test story').tap do |obs|
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs.publish!
      end
    end

    context 'when observation has GIFs' do
      it 'displays GIFs section' do
        visit organization_observation_path(company, observation_with_gifs)
        expect(page).to have_css('h5', text: 'GIFs')
        expect(page).to have_css('[id="observation-gifs"]')
      end

      it 'displays GIFs in responsive Bootstrap grid' do
        visit organization_observation_path(company, observation_with_gifs)
        expect(page).to have_css('.row .col-12.col-md-6.col-lg-4', count: 2)
        expect(page).to have_css('img[src="https://example.com/gif1.gif"]')
        expect(page).to have_css('img[src="https://example.com/gif2.gif"]')
      end
    end

    context 'when observation has no GIFs' do
      it 'does not display GIFs section' do
        visit organization_observation_path(company, observation_without_gifs)
        expect(page).not_to have_css('h5', text: 'GIFs')
        expect(page).not_to have_css('[id="observation-gifs"]')
      end
    end
  end

  describe 'Public Mode in mode switcher' do
    let(:public_observation) do
      build(:observation, observer: observer, company: company, story: 'Test story', privacy_level: 'public_to_world').tap do |obs|
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs.publish!
      end
    end

    let(:private_observation) do
      build(:observation, observer: observer, company: company, story: 'Test story', privacy_level: 'observed_only').tap do |obs|
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs.publish!
      end
    end

    context 'when privacy level is public_to_world' do
      it 'shows Public Mode as clickable link' do
        visit organization_observation_path(company, public_observation)
        
        # Open the dropdown
        find('button.dropdown-toggle').click
        
        expect(page).to have_link('Public Mode', href: organization_kudo_path(company, date: public_observation.observed_at.strftime('%Y-%m-%d'), id: public_observation.id))
        expect(page).to have_css('.dropdown-item i.bi-globe')
      end

      it 'navigates to kudos page when Public Mode is clicked' do
        visit organization_observation_path(company, public_observation)
        
        # Open the dropdown
        find('button.dropdown-toggle').click
        
        click_link 'Public Mode'
        
        expected_path = organization_kudo_path(company, date: public_observation.observed_at.strftime('%Y-%m-%d'), id: public_observation.id)
        expect(page).to have_current_path(expected_path)
      end
    end

    context 'when privacy level is not public_to_world' do
      it 'shows Public Mode as disabled with warning icon' do
        visit organization_observation_path(company, private_observation)
        
        # Open the dropdown
        find('button.dropdown-toggle').click
        
        expect(page).to have_css('.dropdown-item.text-muted.disabled', text: 'Public Mode')
        expect(page).to have_css('.dropdown-item i.bi-globe')
        expect(page).to have_css('.dropdown-item i.bi-exclamation-triangle.text-warning')
      end

      it 'shows tooltip with explanation when hovering over disabled Public Mode' do
        visit organization_observation_path(company, private_observation)
        
        # Open the dropdown
        find('button.dropdown-toggle').click
        
        disabled_item = find('.dropdown-item.disabled', text: 'Public Mode')
        expect(disabled_item).to have_css('[data-bs-toggle="tooltip"]')
        expect(disabled_item.find('[data-bs-toggle="tooltip"]')['data-bs-title']).to eq("Public Mode is only available for observations with 'Public to World' privacy level")
      end
    end
  end
end

