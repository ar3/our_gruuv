require 'rails_helper'

RSpec.describe Organizations::ObservationsController, type: :controller do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee_person) { create(:person) }
  let(:observee_teammate) { create(:teammate, person: observee_person, organization: company) }
  let(:observation) do
    obs = build(:observation, observer: observer, company: company)
    obs.observees.build(teammate: observee_teammate)
    obs.save!
    obs
  end

  before do
    session[:current_person_id] = observer.id
    observer_teammate # Ensure observer teammate is created
  end

  describe 'GET #index' do
    it 'renders the index page' do
      get :index, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns observations' do
      observation # Create the observation
      get :index, params: { organization_id: company.id }
      expect(assigns(:observations)).to include(observation)
    end
  end

  describe 'GET #show' do
    context 'when user is the observer' do
      it 'renders the show page' do
        get :show, params: { organization_id: company.id, id: observation.id }
        expect(response).to have_http_status(:success)
      end
    end

    context 'when user is not the observer' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { create(:teammate, person: other_person, organization: company) }
      
      before do
        session[:current_person_id] = other_person.id
        other_teammate # Ensure teammate is created
      end

      it 'redirects to kudos page' do
        get :show, params: { organization_id: company.id, id: observation.id }
        date_part = observation.observed_at.strftime('%Y-%m-%d')
        expect(response).to redirect_to(kudos_path(date: date_part, id: observation.id))
      end
    end
  end

  describe 'GET #new' do
    it 'renders the new observation form' do
      get :new, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns a new observation' do
      get :new, params: { organization_id: company.id }
      expect(assigns(:observation)).to be_a_new(Observation)
      expect(assigns(:observation).company).to be_a(Organization)
      expect(assigns(:observation).observer).to eq(observer)
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        organization_id: company.id,
        observation: {
          story: 'Great work on the project!',
          privacy_level: 'observed_only',
          primary_feeling: 'happy',
          secondary_feeling: 'proud',
          observed_at: Date.current,
          observees_attributes: {
            '0' => { teammate_id: observee_teammate.id }
          }
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new observation' do
        expect {
          post :create, params: valid_params
        }.to change(Observation, :count).by(1)
      end

      it 'redirects to the observation show page' do
        post :create, params: valid_params
        observation = Observation.last
        expect(response).to redirect_to(organization_observation_path(company, observation))
      end

      it 'sets the correct attributes' do
        post :create, params: valid_params
        observation = Observation.last
        expect(observation.story).to eq('Great work on the project!')
        expect(observation.privacy_level).to eq('observed_only')
        expect(observation.primary_feeling).to eq('happy')
        expect(observation.secondary_feeling).to eq('proud')
        expect(observation.company).to be_a(Organization)
        expect(observation.observer).to eq(observer)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          organization_id: company.id,
          observation: {
            story: '', # Invalid - empty story when publishing
            privacy_level: 'observed_only',
            publishing: 'true'
          }
        }
      end

      it 'does not create a new observation' do
        expect {
          post :create, params: invalid_params
        }.not_to change(Observation, :count)
      end

      it 'renders the new template' do
        post :create, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'GET #edit' do
    context 'when user is the observer' do
      it 'renders the edit form' do
        get :edit, params: { organization_id: company.id, id: observation.id }
        expect(response).to have_http_status(:success)
      end
    end

    context 'when user is not the observer' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { create(:teammate, person: other_person, organization: company) }
      
      before do
        session[:current_person_id] = other_person.id
        other_teammate # Ensure teammate is created
      end

      it 'redirects to kudos page' do
        get :edit, params: { organization_id: company.id, id: observation.id }
        date_part = observation.observed_at.strftime('%Y-%m-%d')
        expect(response).to redirect_to(kudos_path(date: date_part, id: observation.id))
      end
    end
  end

  describe 'PATCH #update' do
    let(:update_params) do
      {
        organization_id: company.id,
        id: observation.id,
        observation: {
          story: 'Updated story content',
          privacy_level: 'public_observation'
        }
      }
    end

    context 'when user is the observer' do
      it 'updates the observation' do
        patch :update, params: update_params
        observation.reload
        expect(observation.story).to eq('Updated story content')
        expect(observation.privacy_level).to eq('public_observation')
      end

      it 'redirects to the observation show page' do
        patch :update, params: update_params
        expect(response).to redirect_to(organization_observation_path(company, observation))
      end
    end

    context 'when user is not the observer' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { create(:teammate, person: other_person, organization: company) }
      
      before do
        session[:current_person_id] = other_person.id
        other_teammate # Ensure teammate is created
      end

      it 'redirects to kudos page' do
        patch :update, params: update_params
        date_part = observation.observed_at.strftime('%Y-%m-%d')
        expect(response).to redirect_to(kudos_path(date: date_part, id: observation.id))
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when user is the observer and within 24 hours' do
      before do
        observation.update_column(:created_at, 1.hour.ago)
      end

      it 'soft deletes the observation' do
        expect {
          delete :destroy, params: { organization_id: company.id, id: observation.id }
        }.to change { observation.reload.deleted_at }.from(nil)
      end

      it 'redirects to observations index' do
        delete :destroy, params: { organization_id: company.id, id: observation.id }
        expect(response).to redirect_to(organization_observations_path(company))
      end
    end

    context 'when user is not the observer' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { create(:teammate, person: other_person, organization: company) }
      
      before do
        session[:current_person_id] = other_person.id
        other_teammate # Ensure teammate is created
      end

      it 'redirects to kudos page' do
        delete :destroy, params: { organization_id: company.id, id: observation.id }
        date_part = observation.observed_at.strftime('%Y-%m-%d')
        expect(response).to redirect_to(kudos_path(date: date_part, id: observation.id))
      end
    end
  end

  describe 'GET #journal' do
    let!(:journal_observation) do
      obs = build(:observation, observer: observer, company: company, privacy_level: :observer_only)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs
    end

    it 'renders the index page with journal filter' do
      get :journal, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:index)
    end

    it 'assigns only journal observations' do
      get :journal, params: { organization_id: company.id }
      expect(assigns(:observations)).to include(journal_observation)
      expect(assigns(:observations)).not_to include(observation) # Non-journal observation
    end
  end

  describe 'GET #quick_new' do
    let(:assignment) { create(:assignment, company: company) }
    
    it 'renders the quick_new form' do
      get :quick_new, params: {
        organization_id: company.id,
        return_url: organization_observations_path(company),
        return_text: 'Check-ins',
        observee_ids: [observee_teammate.id],
        rateable_type: 'Assignment',
        rateable_id: assignment.id,
        privacy_level: 'observed_and_managers'
      }
      expect(response).to have_http_status(:success)
    end

    it 'creates a draft observation when draft_id is not provided' do
      get :quick_new, params: {
        organization_id: company.id,
        return_url: organization_observations_path(company),
        observee_ids: [observee_teammate.id]
      }
      
      # quick_new builds the observation in memory but doesn't save it
      # The observation is saved later via update_draft or publish
      expect(assigns(:observation)).to be_present
      expect(assigns(:observation).published_at).to be_nil
      expect(assigns(:observation).observer).to eq(observer)
      expect(assigns(:observation).observees).to be_present
    end

    it 'loads existing draft when draft_id is provided' do
      draft = build(:observation, observer: observer, company: company, published_at: nil)
      draft.observees.build(teammate: observee_teammate)
      draft.save!
      
      get :quick_new, params: {
        organization_id: company.id,
        draft_id: draft.id,
        return_url: organization_observations_path(company)
      }
      
      expect(assigns(:observation)).to eq(draft)
      expect(assigns(:observation).published_at).to be_nil
    end

    it 'assigns available rateables for the organization' do
      assignment # Create the assignment
      get :quick_new, params: {
        organization_id: company.id,
        observee_ids: [observee_teammate.id]
      }
      expect(assigns(:assignments)).to include(assignment)
    end
  end

  describe 'POST #add_rateables' do
    let(:draft) do
      obs = build(:observation, observer: observer, company: company, published_at: nil)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs
    end
    let(:assignment) { create(:assignment, company: company) }

    it 'adds rateables to the draft' do
      expect {
        post :add_rateables, params: {
          organization_id: company.id,
          id: draft.id,
          rateable_type: 'Assignment',
          rateable_ids: [assignment.id]
        }
      }.to change { draft.observation_ratings.count }.by(1)
      
      expect(draft.reload.published_at).to be_nil
    end

    it 'redirects back to quick_new' do
      post :add_rateables, params: {
        organization_id: company.id,
        id: draft.id,
        rateable_type: 'Assignment',
        rateable_ids: [assignment.id]
      }
      expect(response).to redirect_to(quick_new_organization_observations_path(company, draft_id: draft.id))
    end
  end

  describe 'PATCH #update_draft' do
    let(:draft) do
      obs = build(:observation, observer: observer, company: company, published_at: nil)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs
    end

    it 'updates the draft observation' do
      patch :update_draft, params: {
        organization_id: company.id,
        id: draft.id,
        observation: {
          story: 'Updated story',
          primary_feeling: 'excited'
        }
      }
      draft.reload
      expect(draft.story).to eq('Updated story')
      expect(draft.primary_feeling).to eq('excited')
      expect(draft.published_at).to be_nil
    end
  end

  describe 'POST #publish' do
    let(:draft) do
      obs = build(:observation, observer: observer, company: company, published_at: nil)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs
    end

    it 'sets published_at timestamp' do
      post :publish, params: {
        organization_id: company.id,
        id: draft.id,
        return_url: organization_observations_path(company)
      }
      draft.reload
      expect(draft.published_at).to be_present
    end

    it 'redirects to return_url with show_observations_for param' do
      post :publish, params: {
        organization_id: company.id,
        id: draft.id,
        return_url: organization_observations_path(company),
        show_observations_for: 'assignment_123'
      }
      expect(response).to redirect_to(organization_observations_path(company) + '?show_observations_for=assignment_123')
    end
  end

  # Note: CSRF protection is disabled in test environment (config/environments/test.rb)
  # System specs won't catch CSRF issues because allow_forgery_protection = false
  # This is expected Rails behavior - tests don't validate CSRF tokens
end
