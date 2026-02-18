require 'rails_helper'

RSpec.describe 'Organizations::PublicMaap::Abilities', type: :request do
  let(:company) { create(:organization) }
  let(:department) { create(:department, company: company) }
  let(:created_by) { create(:person) }
  let(:updated_by) { create(:person) }

  let!(:ability_company) do
    create(:ability, company: company, name: 'Company Ability', created_by: created_by, updated_by: updated_by)
  end

  let!(:ability_department) do
    create(:ability, company: company, department: department, name: 'Department Ability', created_by: created_by, updated_by: updated_by)
  end

  let(:observer) { create(:person) }
  let(:observation) do
    obs = create(:observation, observer: observer, company: company, privacy_level: :public_to_world, published_at: Time.current)
    create(:observation_rating, observation: obs, rateable: ability_company, rating: :strongly_agree)
    obs
  end

  describe 'GET /organizations/:organization_id/public_maap/abilities' do
    it 'renders successfully without authentication' do
      get organization_public_maap_abilities_path(company)
      expect(response).to have_http_status(:success)
    end

    it 'shows abilities in the list' do
      get organization_public_maap_abilities_path(company)
      # Department-level abilities are listed; company-level may be in a separate section
      expect(response.body).to include(ability_department.name)
    end

    it 'shows link to authenticated version when user is logged in' do
      person = create(:person)
      sign_in_as_teammate_for_request(person, company)

      get organization_public_maap_abilities_path(company)
      expect(response.body).to include('View Authenticated Version')
    end

    it 'does not show link to authenticated version when user is not logged in' do
      get organization_public_maap_abilities_path(company)
      expect(response.body).not_to include('View Authenticated Version')
    end

    it 'excludes archived abilities from index' do
      archived = create(:ability, company: company, name: 'Archived Ability', created_by: created_by, updated_by: updated_by)
      archived.update_columns(deleted_at: 1.day.ago)
      get organization_public_maap_abilities_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('Archived Ability')
    end
  end

  describe 'GET /organizations/:organization_id/public_maap/abilities/:id' do
    before { observation }

    it 'renders successfully without authentication' do
      get organization_public_maap_ability_path(company, ability_company)
      expect(response).to have_http_status(:success)
    end

    it 'displays ability name' do
      get organization_public_maap_ability_path(company, ability_company)
      expect(response.body).to include('Company Ability')
    end

    it 'displays organization detail row with company display_name' do
      get organization_public_maap_ability_path(company, ability_company)
      expect(response.body).to include(ability_company.company.display_name)
    end

    it 'displays public and published observations' do
      private_obs = create(:observation, observer: observer, company: company, privacy_level: :observer_only, published_at: Time.current)
      create(:observation_rating, observation: private_obs, rateable: ability_company, rating: :agree)

      draft_obs = create(:observation, observer: observer, company: company, privacy_level: :public_to_world, published_at: nil)
      create(:observation_rating, observation: draft_obs, rateable: ability_company, rating: :agree)

      get organization_public_maap_ability_path(company, ability_company)

      expect(response.body).to include('Public Observations')
      expect(response.body).to include(observation.decorate.story_html)
      expect(response.body).not_to include(private_obs.decorate.story_html)
      expect(response.body).not_to include(draft_obs.decorate.story_html)
    end

    it 'handles id-name-parameterized format' do
      param = ability_company.to_param
      get organization_public_maap_ability_path(company, param)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Company Ability')
    end

    it 'shows "View Authenticated Version" when user is logged in' do
      person = create(:person)
      sign_in_as_teammate_for_request(person, company)

      get organization_public_maap_ability_path(company, ability_company)
      expect(response.body).to include('View Authenticated Version')
    end

    it 'does not show "View Authenticated Version" when user is not logged in' do
      get organization_public_maap_ability_path(company, ability_company)
      expect(response.body).not_to include('View Authenticated Version')
    end

    context 'when ability is archived' do
      before { ability_company.update_columns(deleted_at: 1.day.ago) }

      it 'displays archived banner' do
        get organization_public_maap_ability_path(company, ability_company)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Archived as of')
      end
    end
  end
end
