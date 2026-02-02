require 'rails_helper'

RSpec.describe Organizations::KudosController, type: :controller do
  let(:company) { create(:organization, name: 'Test Company') }
  let(:department) { create(:department, company: company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee_person) { create(:person) }
  let(:observee_teammate) { create(:teammate, person: observee_person, organization: company) }
  let(:observation) do
    obs = build(:observation, observer: observer, company: company, observed_at: Date.parse('2025-10-05'))
    obs.observees.build(teammate: observee_teammate)
    obs.save!
    obs.publish! # Publish so observees can view it (drafts are only visible to creator)
    obs
  end

  before do
    observer_teammate # Ensure observer teammate is created
  end

  describe 'GET #index' do
    let!(:public_to_world) do
      obs = create(:observation, observer: observer, company: company, privacy_level: :public_to_world, published_at: Time.current, observed_at: 2.days.ago)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs
    end

    let!(:department_observation) do
      obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_world, published_at: Time.current, observed_at: 1.day.ago)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs
    end

    let!(:private_observation) do
      obs = create(:observation, observer: observer, company: company, privacy_level: :observer_only, published_at: Time.current, observed_at: 3.days.ago)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs
    end

    let!(:unpublished_observation) do
      obs = build(:observation, observer: observer, company: company, privacy_level: :public_to_world, published_at: nil, observed_at: 4.days.ago)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs
    end

    it 'renders successfully without authentication' do
      get :index, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the organization' do
      get :index, params: { organization_id: company.id }
      expect(assigns(:organization).id).to eq(company.id)
      expect(assigns(:organization)).to be_a(Organization)
    end

    it 'shows public observations for organization and descendants' do
      get :index, params: { organization_id: company.id }
      observations = assigns(:observations)
      
      expect(observations).to include(public_to_world)
      expect(observations).to include(department_observation)
      expect(observations).not_to include(private_observation)
      expect(observations).not_to include(unpublished_observation)
    end

    it 'excludes non-public observations' do
      get :index, params: { organization_id: company.id }
      observations = assigns(:observations)
      
      expect(observations).not_to include(private_observation)
    end

    it 'excludes unpublished observations' do
      get :index, params: { organization_id: company.id }
      observations = assigns(:observations)
      
      expect(observations).not_to include(unpublished_observation)
    end

    it 'excludes soft-deleted observations' do
      soft_deleted = create(:observation, observer: observer, company: company, privacy_level: :public_to_world, published_at: Time.current, observed_at: 5.days.ago)
      soft_deleted.observees.build(teammate: observee_teammate)
      soft_deleted.save!
      soft_deleted.soft_delete!
      
      get :index, params: { organization_id: company.id }
      observations = assigns(:observations)
      
      expect(observations).not_to include(soft_deleted)
      expect(observations).to include(public_to_world)
    end

    it 'handles id-name-parameterized format' do
      param = "#{company.id}-test-company"
      get :index, params: { organization_id: param }
      expect(assigns(:organization).id).to eq(company.id)
      expect(assigns(:organization)).to be_a(Organization)
    end

    it 'raises error for invalid organization' do
      expect {
        get :index, params: { organization_id: '999999' }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'uses public_maap layout' do
      get :index, params: { organization_id: company.id }
      expect(response).to render_template(layout: 'public_maap')
    end
  end

  describe 'GET #show' do
    context 'with public observation' do
      before do
        observation.update!(privacy_level: :public_to_world)
      end

      it 'renders the kudos page without authentication' do
        get :show, params: { organization_id: company.id, date: '2025-10-05', id: observation.id }
        expect(response).to have_http_status(:success)
      end

      it 'assigns the observation' do
        get :show, params: { organization_id: company.id, date: '2025-10-05', id: observation.id }
        expect(assigns(:observation)).to eq(observation)
      end

      it 'sets @organization from observation company' do
        get :show, params: { organization_id: company.id, date: '2025-10-05', id: observation.id }
        expect(assigns(:organization).id).to eq(company.id)
        expect(assigns(:organization)).to be_a(Organization)
      end

      it 'uses public_maap layout' do
        get :show, params: { organization_id: company.id, date: '2025-10-05', id: observation.id }
        expect(response).to render_template(layout: 'public_maap')
      end
    end

    context 'with observer_only observation' do
      before do
        observation.update!(privacy_level: :observer_only)
      end

      context 'when user is authenticated and is the observer' do
        before do
          sign_in_as_teammate(observer, company)
        end

        it 'redirects with authorization error (permalink is public-only)' do
          get :show, params: { organization_id: company.id, date: '2025-10-05', id: observation.id }
          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to eq("You are not authorized to view this observation")
        end
      end

      context 'when user is not authenticated' do
        it 'redirects to login' do
          get :show, params: { organization_id: company.id, date: '2025-10-05', id: observation.id }
          expect(response).to redirect_to(root_path)
        end
      end

      context 'when user is authenticated but not the observer' do
        let(:other_person) { create(:person) }
        let(:other_teammate) { create(:teammate, person: other_person, organization: company) }
        
        before do
          sign_in_as_teammate(other_person, company)
        end

        it 'redirects with authorization error' do
          get :show, params: { organization_id: company.id, date: '2025-10-05', id: observation.id }
          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to eq("You are not authorized to view this observation")
        end
      end
    end

    context 'with observed_only observation' do
      before do
        observation.update!(privacy_level: :observed_only)
      end

      context 'when user is the observer' do
        before do
          sign_in_as_teammate(observer, company)
        end

        it 'redirects with authorization error (permalink is public-only)' do
          get :show, params: { organization_id: company.id, date: '2025-10-05', id: observation.id }
          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to eq("You are not authorized to view this observation")
        end
      end

      context 'when user is an observee' do
        before do
          sign_in_as_teammate(observee_person, company)
        end

        it 'redirects with authorization error (permalink is public-only)' do
          get :show, params: { organization_id: company.id, date: '2025-10-05', id: observation.id }
          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to eq("You are not authorized to view this observation")
        end
      end

      context 'when user is neither observer nor observee' do
        let(:other_person) { create(:person) }
        let(:other_teammate) { create(:teammate, person: other_person, organization: company) }
        
        before do
          sign_in_as_teammate(other_person, company)
        end

        it 'redirects with authorization error' do
          get :show, params: { organization_id: company.id, date: '2025-10-05', id: observation.id }
          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to eq("You are not authorized to view this observation")
        end
      end
    end

    context 'with invalid permalink' do
      it 'raises RecordNotFound' do
        expect {
          get :show, params: { organization_id: company.id, date: '2025-10-05', id: 99999 }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with custom slug in permalink' do
      before do
        observation.update!(custom_slug: 'awesome-work', privacy_level: :public_to_world)
      end

      it 'finds the observation by date and id, ignoring slug' do
        get :show, params: { organization_id: company.id, date: '2025-10-05', id: observation.id }
        expect(response).to have_http_status(:success)
        expect(assigns(:observation)).to eq(observation)
      end
    end

    context 'with organization lookup by param' do
      before do
        observation.update!(privacy_level: :public_to_world)
      end

      it 'handles id-name-parameterized format' do
        param = "#{company.id}-test-company"
        get :show, params: { organization_id: param, date: '2025-10-05', id: observation.id }
        expect(assigns(:organization).id).to eq(company.id)
        expect(response).to have_http_status(:success)
      end
    end

    context 'with soft-deleted observation' do
      before do
        observation.update!(privacy_level: :public_to_world)
        observation.soft_delete!
      end

      it 'denies access (redirects with alert)' do
        get :show, params: { organization_id: company.id, date: '2025-10-05', id: observation.id }
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to be_present
      end
    end
  end
end

