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
    sign_in_as_teammate(observer, company)
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
        sign_in_as_teammate(other_person, company)
      end

      it 'redirects to kudos page' do
        get :show, params: { organization_id: company.id, id: observation.id }
        date_part = observation.observed_at.strftime('%Y-%m-%d')
        expect(response).to redirect_to(kudos_path(date: date_part, id: observation.id))
      end
    end
  end

  describe 'GET #new' do
    it 'renders the new form (overlay layout)' do
      get :new, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:new)
      expect(response).to render_template(layout: 'overlay')
    end

    it 'assigns a new observation' do
      get :new, params: { organization_id: company.id }
      expect(assigns(:observation)).to be_a_new(Observation)
      expect(assigns(:observation).company_id).to eq(company.id)
      expect(assigns(:observation).observer).to eq(observer)
    end

    it 'accepts return_url and return_text params' do
      get :new, params: {
        organization_id: company.id,
        return_url: organization_observations_path(company),
        return_text: 'Back to Observations'
      }
      expect(assigns(:return_url)).to eq(organization_observations_path(company))
      expect(assigns(:return_text)).to eq('Back to Observations')
    end

    it 'sets default return_url and return_text when not provided' do
      get :new, params: { organization_id: company.id }
      expect(assigns(:return_url)).to eq(organization_observations_path(company))
      expect(assigns(:return_text)).to eq('Back')
    end

    it 'accepts draft_id to load existing draft' do
      draft = build(:observation, observer: observer, company: company, published_at: nil)
      draft.observees.build(teammate: observee_teammate)
      draft.save!
      
      get :new, params: {
        organization_id: company.id,
        draft_id: draft.id
      }
      expect(assigns(:observation)).to eq(draft)
      expect(assigns(:observation).published_at).to be_nil
    end

    it 'accepts observee_ids to pre-populate observees' do
      get :new, params: {
        organization_id: company.id,
        observee_ids: [observee_teammate.id]
      }
      expect(assigns(:observation).observees).to be_present
      expect(assigns(:observation).observees.first.teammate_id).to eq(observee_teammate.id)
    end

    it 'assigns available rateables for the organization' do
      assignment = create(:assignment, company: company)
      get :new, params: { organization_id: company.id }
      expect(assigns(:assignments)).to include(assignment)
      expect(assigns(:aspirations)).to be_a(ActiveRecord::Associations::CollectionProxy)
      expect(assigns(:abilities)).to be_a(ActiveRecord::Relation)
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

  describe 'GET #new with published observation (editing)' do
    let(:published_observation) do
      obs = build(:observation, observer: observer, company: company, published_at: Time.current)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs
    end

    context 'when user is the observer' do
      it 'loads the published observation via id param' do
        get :new, params: {
          organization_id: company.id,
          id: published_observation.id
        }
        expect(assigns(:observation)).to eq(published_observation)
        expect(assigns(:observation).published_at).to be_present
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:new)
        expect(response).to render_template(layout: 'overlay')
      end

      it 'loads the published observation via draft_id param' do
        get :new, params: {
          organization_id: company.id,
          draft_id: published_observation.id
        }
        expect(assigns(:observation)).to eq(published_observation)
        expect(assigns(:observation).published_at).to be_present
      end

      it 'sets default return_url to show page when editing published observation' do
        get :new, params: {
          organization_id: company.id,
          id: published_observation.id
        }
        expect(assigns(:return_url)).to eq(organization_observation_path(company, published_observation))
        expect(assigns(:return_text)).to eq('Back to Observation')
      end

      it 'accepts custom return_url and return_text when editing' do
        get :new, params: {
          organization_id: company.id,
          id: published_observation.id,
          return_url: organization_observations_path(company),
          return_text: 'Back to List'
        }
        expect(assigns(:return_url)).to eq(organization_observations_path(company))
        expect(assigns(:return_text)).to eq('Back to List')
      end
    end

    context 'when user is not the observer' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { create(:teammate, person: other_person, organization: company) }
      
      before do
        sign_in_as_teammate(other_person, company)
      end

      it 'redirects with authorization error' do
        get :new, params: {
          organization_id: company.id,
          id: published_observation.id
        }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("don't have permission")
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
        sign_in_as_teammate(other_person, company)
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
    
    it 'redirects to new action with all parameters' do
      get :quick_new, params: {
        organization_id: company.id,
        return_url: organization_observations_path(company),
        return_text: 'Check-ins',
        observee_ids: [observee_teammate.id],
        rateable_type: 'Assignment',
        rateable_id: assignment.id,
        privacy_level: 'observed_and_managers'
      }
      expect(response).to redirect_to(new_organization_observation_path(
        company,
        return_url: organization_observations_path(company),
        return_text: 'Check-ins',
        observee_ids: [observee_teammate.id],
        rateable_type: 'Assignment',
        rateable_id: assignment.id,
        privacy_level: 'observed_and_managers'
      ))
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

    it 'redirects back to new' do
      post :add_rateables, params: {
        organization_id: company.id,
        id: draft.id,
        rateable_type: 'Assignment',
        rateable_ids: [assignment.id]
      }
      expect(response).to redirect_to(new_organization_observation_path(company, draft_id: draft.id))
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

    it 'saves story_extras with gif_urls' do
      patch :update_draft, params: {
        organization_id: company.id,
        id: draft.id,
        observation: {
          story: 'Test story',
          privacy_level: 'observer_only',
          story_extras: {
            gif_urls: ['https://media.giphy.com/media/test1/giphy.gif', 'https://media.giphy.com/media/test2/giphy.gif']
          }
        }
      }
      draft.reload
      expect(draft.story_extras).to eq({ 'gif_urls' => ['https://media.giphy.com/media/test1/giphy.gif', 'https://media.giphy.com/media/test2/giphy.gif'] })
    end


    context 'when saving a published observation as draft' do
      let(:published_observation) do
        obs = build(:observation, observer: observer, company: company, published_at: 1.day.ago)
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs
      end

      it 'converts published observation to draft when save_draft_and_return is present' do
        expect(published_observation.published_at).to be_present
        
        patch :update_draft, params: {
          organization_id: company.id,
          id: published_observation.id,
          save_draft_and_return: '1',
          observation: {
            story: 'Updated story',
            primary_feeling: 'excited'
          },
          return_url: organization_observations_path(company)
        }
        
        published_observation.reload
        expect(published_observation.published_at).to be_nil
        expect(published_observation.draft?).to be true
      end
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

    it 'redirects to show page when return_url is not provided (publish from show page)' do
      post :publish, params: {
        organization_id: company.id,
        id: draft.id
      }
      expect(response).to redirect_to(organization_observation_path(company, draft))
    end

    it 'fails gracefully if validation errors occur when publishing from show page' do
      # Create a draft without required fields
      invalid_draft = build(:observation, observer: observer, company: company, published_at: nil, story: nil)
      invalid_draft.observees.build(teammate: observee_teammate)
      invalid_draft.save!
      
      post :publish, params: {
        organization_id: company.id,
        id: invalid_draft.id
      }
      invalid_draft.reload
      expect(invalid_draft.published_at).to be_nil
      expect(response).to redirect_to(organization_observation_path(company, invalid_draft))
      expect(flash[:alert]).to be_present
    end
  end

  describe 'GET #manage_observees' do
    let(:draft) do
      obs = build(:observation, observer: observer, company: company, published_at: nil)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs
    end
    let(:other_teammate) { create(:teammate, organization: company) }

    it 'renders the manage_observees template' do
      get :manage_observees, params: { organization_id: company.id, id: draft.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:manage_observees)
      expect(response).to render_template(layout: 'overlay')
    end

    it 'assigns all teammates (not just unselected)' do
      get :manage_observees, params: { organization_id: company.id, id: draft.id }
      expect(assigns(:teammates)).to include(observee_teammate)
      expect(assigns(:teammates)).to include(other_teammate)
    end

    it 'requires authorization' do
      other_person = create(:person)
      other_teammate_user = create(:teammate, person: other_person, organization: company)
      sign_in_as_teammate(other_person, company)
      
      get :manage_observees, params: { organization_id: company.id, id: draft.id }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe 'PATCH #manage_observees' do
    let(:draft) do
      # Build observation without factory callback to avoid extra observee
      obs = Observation.new(observer: observer, company: company, published_at: nil, privacy_level: :observed_only, primary_feeling: 'happy', observed_at: Time.current)
      obs.observees.build(teammate: observee_teammate)
      obs.save!
      obs
    end
    let(:new_teammate) { create(:teammate, organization: company) }
    let(:another_teammate) { create(:teammate, organization: company) }

    context 'when adding new observees' do
      it 'adds new observees when teammates are checked' do
        expect {
          patch :manage_observees, params: {
            organization_id: company.id,
            id: draft.id,
            teammate_ids: [observee_teammate.id, new_teammate.id]
          }
        }.to change { draft.observees.count }.by(1)
        
        expect(draft.reload.observees.pluck(:teammate_id)).to include(observee_teammate.id, new_teammate.id)
      end

      it 'shows appropriate success message when adding' do
        patch :manage_observees, params: {
          organization_id: company.id,
          id: draft.id,
          teammate_ids: [observee_teammate.id, new_teammate.id]
        }
        expect(flash[:notice]).to include('Added 1 observee(s)')
      end
    end

    context 'when removing observees' do
      it 'removes observees when teammates are unchecked' do
        expect {
          patch :manage_observees, params: {
            organization_id: company.id,
            id: draft.id,
            teammate_ids: []
          }
        }.to change { draft.observees.count }.by(-1)
        
        expect(draft.reload.observees.pluck(:teammate_id)).not_to include(observee_teammate.id)
      end

      it 'shows appropriate success message when removing' do
        patch :manage_observees, params: {
          organization_id: company.id,
          id: draft.id,
          teammate_ids: []
        }
        expect(flash[:notice]).to include('Removed 1 observee(s)')
      end
    end

    context 'when adding and removing in same submission' do
      before do
        draft.observees.create!(teammate: another_teammate)
      end

      it 'handles mixed add/remove in single submission' do
        expect {
          patch :manage_observees, params: {
            organization_id: company.id,
            id: draft.id,
            teammate_ids: [observee_teammate.id, new_teammate.id]
          }
        }.to change { draft.observees.count }.by(0) # One removed, one added
        
        expect(draft.reload.observees.pluck(:teammate_id)).to include(observee_teammate.id, new_teammate.id)
        expect(draft.reload.observees.pluck(:teammate_id)).not_to include(another_teammate.id)
      end

      it 'shows appropriate success message for mixed operations' do
        patch :manage_observees, params: {
          organization_id: company.id,
          id: draft.id,
          teammate_ids: [observee_teammate.id, new_teammate.id]
        }
        expect(flash[:notice]).to include('Added 1 observee(s) and removed 1 observee(s)')
      end
    end

    context 'when no changes are made' do
      it 'shows no changes message' do
        patch :manage_observees, params: {
          organization_id: company.id,
          id: draft.id,
          teammate_ids: [observee_teammate.id]
        }
        expect(flash[:notice]).to eq('No changes made')
      end
    end

    context 'edge cases' do
      it 'handles empty selection (all removed)' do
        expect {
          patch :manage_observees, params: {
            organization_id: company.id,
            id: draft.id,
            teammate_ids: []
          }
        }.to change { draft.observees.count }.by(-1)
      end

      it 'handles all teammates selected (all added)' do
        new_teammate2 = create(:teammate, organization: company)
        expect {
          patch :manage_observees, params: {
            organization_id: company.id,
            id: draft.id,
            teammate_ids: [observee_teammate.id, new_teammate.id, new_teammate2.id]
          }
        }.to change { draft.observees.count }.by(2)
      end

      it 'redirects back to new observation page with correct params' do
        patch :manage_observees, params: {
          organization_id: company.id,
          id: draft.id,
          teammate_ids: [observee_teammate.id],
          return_url: organization_observations_path(company),
          return_text: 'Back to Observations'
        }
        expect(response).to redirect_to(new_organization_observation_path(
          company,
          draft_id: draft.id,
          return_url: organization_observations_path(company),
          return_text: 'Back to Observations'
        ))
      end
    end

    it 'requires authorization' do
      other_person = create(:person)
      other_teammate_user = create(:teammate, person: other_person, organization: company)
      sign_in_as_teammate(other_person, company)
      
      patch :manage_observees, params: {
        organization_id: company.id,
        id: draft.id,
        teammate_ids: []
      }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be_present
    end
  end

  # Note: CSRF protection is disabled in test environment (config/environments/test.rb)
  # System specs won't catch CSRF issues because allow_forgery_protection = false
  # This is expected Rails behavior - tests don't validate CSRF tokens
end
