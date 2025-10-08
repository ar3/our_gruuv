require 'rails_helper'

RSpec.describe Organizations::ObservationsController, type: :controller do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee1) { create(:teammate, organization: company) }
  let(:observee2) { create(:teammate, organization: company) }
  let(:ability) { create(:ability, organization: company) }
  let(:assignment) { create(:assignment, company: company) }

  before do
    session[:current_person_id] = observer.id
    observer_teammate # Ensure observer teammate is created
  end

  describe 'Wizard Flow' do
    describe 'Step 1: Who, When, What, How' do
      context 'with valid step 1 data' do
        let(:step1_params) do
          {
            organization_id: company.id,
            observation: {
              story: 'Great work on the project!',
              primary_feeling: 'happy',
              secondary_feeling: 'proud',
              observed_at: Date.current,
              teammate_ids: [observee1.id.to_s, observee2.id.to_s]
            },
            step: '2'
          }
        end

        it 'redirects to step 2 with observation in session' do
          post :create, params: step1_params
          
          expect(response).to redirect_to(set_ratings_organization_observation_path(company, 'new'))
          expect(session[:observation_wizard_data]).to be_present
          expect(session[:observation_wizard_data]['story']).to eq('Great work on the project!')
          expect(session[:observation_wizard_data]['teammate_ids']).to eq([observee1.id.to_s, observee2.id.to_s])
        end
      end

      context 'with invalid step 1 data' do
        let(:invalid_step1_params) do
          {
            organization_id: company.id,
            observation: {
              story: '', # Invalid - empty story
              teammate_ids: []
            },
            step: '2'
          }
        end

        it 'renders step 1 with validation errors' do
          post :create, params: invalid_step1_params
          
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to render_template(:new)
          expect(assigns(:form).errors[:story]).to include("can't be blank")
          expect(assigns(:form).errors[:observees]).to include('must have at least one observee')
        end
      end
    end

    describe 'Step 2: Ratings & Privacy' do
      let(:wizard_data) do
        {
          'story' => 'Great work!',
          'primary_feeling' => 'happy',
          'secondary_feeling' => 'proud',
          'observed_at' => Date.current.to_s,
          'teammate_ids' => [observee1.id.to_s, observee2.id.to_s]
        }
      end

      before do
        session[:observation_wizard_data] = wizard_data
      end

      context 'GET set_ratings' do
        it 'renders step 2 form with wizard data' do
          get :set_ratings, params: { organization_id: company.id, id: 'new' }
          
          expect(response).to have_http_status(:success)
          expect(response).to render_template(:set_ratings)
          expect(assigns(:form).story).to eq('Great work!')
          expect(assigns(:form).teammate_ids).to eq([observee1.id.to_s, observee2.id.to_s])
        end

        it 'shows available abilities and assignments for selected observees' do
          get :set_ratings, params: { organization_id: company.id, id: 'new' }
          
          expect(assigns(:available_abilities)).to include(ability)
          expect(assigns(:available_assignments)).to include(assignment)
        end
      end

      context 'POST set_ratings' do
        let(:step2_params) do
          {
            organization_id: company.id,
            id: 'new',
            observation: {
              privacy_level: 'observed_only',
              observation_ratings_attributes: {
                '0' => { rateable_type: 'Ability', rateable_id: ability.id, rating: 'strongly_agree' },
                '1' => { rateable_type: 'Assignment', rateable_id: assignment.id, rating: 'agree' }
              }
            },
            step: '3'
          }
        end

        before do
          # Ensure session data is set before the POST request
          session[:observation_wizard_data] = wizard_data
        end

        it 'redirects to step 3 with updated wizard data' do
          # Set session data directly in the test
          session[:observation_wizard_data] = wizard_data
          
          # Debug: Check session data before request
          expect(session[:observation_wizard_data]).to be_present
          
          post :set_ratings, params: step2_params
          
          expect(response).to redirect_to(review_organization_observation_path(company, 'new'))
          expect(session[:observation_wizard_data]['privacy_level']).to eq('observed_only')
          expect(session[:observation_wizard_data]['observation_ratings_attributes']).to be_present
        end
      end
    end

    describe 'Step 3: Review & Manage' do
      let(:wizard_data) do
        {
          'story' => 'Great work!',
          'primary_feeling' => 'happy',
          'secondary_feeling' => 'proud',
          'observed_at' => Date.current.to_s,
          'teammate_ids' => [observee1.id.to_s, observee2.id.to_s],
          'privacy_level' => 'observed_only',
          'observation_ratings_attributes' => {
            '0' => { rateable_type: 'Ability', rateable_id: ability.id.to_s, rating: 'strongly_agree' }
          }
        }
      end

      before do
        session[:observation_wizard_data] = wizard_data
      end

      context 'GET review' do
        it 'renders step 3 review page' do
          get :review, params: { organization_id: company.id, id: 'new' }
          
          expect(response).to have_http_status(:success)
          expect(response).to render_template(:review)
          expect(assigns(:form).story).to eq('Great work!')
          expect(assigns(:form).privacy_level).to eq('observed_only')
        end

        it 'shows notification options for observees' do
          get :review, params: { organization_id: company.id, id: 'new' }
          
          expect(assigns(:observees_for_notifications)).to include(observee1)
          expect(assigns(:observees_for_notifications)).to include(observee2)
        end
      end

      context 'POST create_observation' do
        let(:final_params) do
          {
            organization_id: company.id,
            id: 'new',
            observation: {
              send_notifications: '1',
              notify_teammate_ids: [observee1.id.to_s, observee2.id.to_s]
            }
          }
        end

        it 'creates observation and redirects to show page' do
          expect {
            post :create_observation, params: final_params
          }.to change(Observation, :count).by(1)
           .and change(Observee, :count).by(2)
           .and change(ObservationRating, :count).by(1)

          observation = Observation.last
          expect(response).to redirect_to(organization_observation_path(company, observation))
          expect(session[:observation_wizard_data]).to be_nil
        end

        it 'sends Slack notifications when requested' do
          expect(Observations::PostNotificationJob).to receive(:perform_later).with(kind_of(Integer), [observee1.id.to_s, observee2.id.to_s])
          
          post :create_observation, params: final_params
        end
      end
    end

    describe 'Slack posting from show page' do
      let(:observation) do
        obs = build(:observation, observer: observer, company: company, story: 'Test story')
        obs.observees.build(teammate: observee1)
        obs.save!
        obs
      end

      context 'POST post_to_slack' do
        let(:slack_params) do
          {
            organization_id: company.id,
            id: observation.id,
            notify_teammate_ids: [observee1.id.to_s]
          }
        end

        it 'sends Slack notifications and redirects back to show page' do
          expect(Observations::PostNotificationJob).to receive(:perform_later).with(observation.id, [observee1.id.to_s])
          
          post :post_to_slack, params: slack_params
          
          expect(response).to redirect_to(organization_observation_path(company, observation))
          expect(flash[:notice]).to include('Notifications sent successfully')
        end
      end
    end
  end
end
