require 'rails_helper'

RSpec.describe 'Observation Creation Wizard Integration', type: :request do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let(:observee1) { create(:teammate, organization: company) }
  let(:observee2) { create(:teammate, organization: company) }
  let(:ability) { create(:ability, organization: company) }
  let(:assignment) { create(:assignment, company: company) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(observer)
    observer_teammate # Ensure observer teammate is created
  end

  describe 'Complete wizard flow' do
    it 'creates observation through all wizard steps' do
      # Step 1: Create observation with basic data
      step1_params = {
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

      post organization_observations_path(company), params: step1_params
      expect(response).to redirect_to(set_ratings_organization_observation_path(company, 'new'))

      # Follow the redirect to step 2
      follow_redirect!
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:set_ratings)

      # Step 2: Add ratings and privacy
      step2_params = {
        organization_id: company.id,
        observation: {
          privacy_level: 'observed_only',
          observation_ratings_attributes: {
            '0' => { rateable_type: 'Ability', rateable_id: ability.id, rating: 'strongly_agree' },
            '1' => { rateable_type: 'Assignment', rateable_id: assignment.id, rating: 'agree' }
          }
        },
        step: '3'
      }

      post set_ratings_organization_observation_path(company, 'new'), params: step2_params
      expect(response).to redirect_to(review_organization_observation_path(company, 'new'))

      # Follow the redirect to step 3
      follow_redirect!
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:review)

      # Step 3: Final creation
      step3_params = {
        organization_id: company.id,
        observation: {
          send_notifications: '1',
          notify_teammate_ids: [observee1.id.to_s, observee2.id.to_s]
        }
      }

      expect {
        post create_observation_organization_observation_path(company, 'new'), params: step3_params
      }.to change(Observation, :count).by(1)
       .and change(Observee, :count).by(2)
       .and change(ObservationRating, :count).by(2)

      observation = Observation.last
      expect(response).to redirect_to(organization_observation_path(company, observation))
      
      # Verify the observation was created correctly
      expect(observation.story).to eq('Great work on the project!')
      expect(observation.privacy_level).to eq('observed_only')
      expect(observation.primary_feeling).to eq('happy')
      expect(observation.secondary_feeling).to eq('proud')
      expect(observation.observees.count).to eq(2)
      expect(observation.observation_ratings.count).to eq(2)
    end
  end
end
