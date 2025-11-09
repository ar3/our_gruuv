require 'rails_helper'

RSpec.describe KudosController, type: :controller do
  let(:company) { create(:organization, :company) }
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

  describe 'GET #show' do
    context 'with public observation' do
      before do
        observation.update!(privacy_level: :public_observation)
      end

      it 'renders the kudos page without authentication' do
        get :show, params: { date: '2025-10-05', id: observation.id }
        expect(response).to have_http_status(:success)
      end

      it 'assigns the observation' do
        get :show, params: { date: '2025-10-05', id: observation.id }
        expect(assigns(:observation)).to eq(observation)
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

        it 'renders the kudos page' do
          get :show, params: { date: '2025-10-05', id: observation.id }
          expect(response).to have_http_status(:success)
        end
      end

      context 'when user is not authenticated' do
      it 'redirects to login' do
        get :show, params: { date: '2025-10-05', id: observation.id }
        expect(response).to redirect_to(root_path)
      end
      end

      context 'when user is authenticated but not the observer' do
        let(:other_person) { create(:person) }
        let(:other_teammate) { create(:teammate, person: other_person, organization: company) }
        
        before do
          sign_in_as_teammate(other_person, company)
        end

        it 'raises NotAuthorizedError' do
          expect {
            get :show, params: { date: '2025-10-05', id: observation.id }
          }.to raise_error(Pundit::NotAuthorizedError)
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

        it 'renders the kudos page' do
          get :show, params: { date: '2025-10-05', id: observation.id }
          expect(response).to have_http_status(:success)
        end
      end

      context 'when user is an observee' do
        before do
          sign_in_as_teammate(observee_person, company)
        end

        it 'renders the kudos page' do
          get :show, params: { date: '2025-10-05', id: observation.id }
          expect(response).to have_http_status(:success)
        end
      end

      context 'when user is neither observer nor observee' do
        let(:other_person) { create(:person) }
        let(:other_teammate) { create(:teammate, person: other_person, organization: company) }
        
        before do
          sign_in_as_teammate(other_person, company)
        end

        it 'raises NotAuthorizedError' do
          expect {
            get :show, params: { date: '2025-10-05', id: observation.id }
          }.to raise_error(Pundit::NotAuthorizedError)
        end
      end
    end

    context 'with invalid permalink' do
      it 'raises RecordNotFound' do
        expect {
          get :show, params: { date: '2025-10-05', id: 99999 }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with custom slug in permalink' do
      before do
        observation.update!(custom_slug: 'awesome-work', privacy_level: :public_observation)
      end

      it 'finds the observation by date and id, ignoring slug' do
        get :show, params: { date: '2025-10-05', id: observation.id }
        expect(response).to have_http_status(:success)
        expect(assigns(:observation)).to eq(observation)
      end
    end
  end
end
