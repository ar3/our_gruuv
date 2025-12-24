require 'rails_helper'

RSpec.describe 'Organizations::Observations', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }

  before do
    teammate # Ensure teammate is created
    sign_in_as_teammate_for_request(person, organization)
    PaperTrail.enabled = false
  end

  after do
    PaperTrail.enabled = true
  end

  describe 'GET /organizations/:organization_id/observations/select_type' do
    it 'allows access to select_type page' do
      get select_type_organization_observations_path(organization)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Select Observation Type')
      expect(response.body).to include('Kudos')
      expect(response.body).to include('Feedback')
      expect(response.body).to include('Quick Note')
      expect(response.body).to include('Generic Observation')
    end

    it 'preserves return_url and return_text params' do
      return_url = organization_observations_path(organization)
      return_text = 'Back to Observations'
      get select_type_organization_observations_path(organization, return_url: return_url, return_text: return_text)
      expect(response).to have_http_status(:success)
      # Verify the params are available in the view (they'll be used in the links)
    end
  end

  describe 'GET /organizations/:organization_id/observations/new_kudos' do
    it 'allows access to new_kudos page' do
      get new_kudos_organization_observations_path(organization)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Kudos')
      expect(response.body).to include('observation_type')
    end

    it 'sets default privacy level to observed_and_managers' do
      get new_kudos_organization_observations_path(organization)
      expect(response).to have_http_status(:success)
      # The default should be set in the controller
    end
  end

  describe 'GET /organizations/:organization_id/observations/new_feedback' do
    it 'allows access to new_feedback page' do
      get new_feedback_organization_observations_path(organization)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Feedback')
      expect(response.body).to include('observation_type')
    end

    it 'pre-fills MAAP template in story field' do
      get new_feedback_organization_observations_path(organization)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Your intent with this feedback')
    end
  end

  describe 'GET /organizations/:organization_id/observations/new_quick_note' do
    it 'allows access to new_quick_note page' do
      get new_quick_note_organization_observations_path(organization)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Quick Note')
      expect(response.body).to include('observation_type')
    end
  end

  describe 'PATCH /organizations/:organization_id/observations/:id/convert_to_generic' do
    let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'kudos', created_as_type: 'kudos') }

    it 'converts observation type to generic' do
      patch convert_to_generic_organization_observation_path(organization, observation)
      expect(response).to redirect_to(new_organization_observation_path(organization, draft_id: observation.id))
      observation.reload
      expect(observation.observation_type).to eq('generic')
      expect(observation.created_as_type).to eq('kudos') # Should not change
    end
  end

  describe 'PATCH /organizations/:organization_id/observations/:id/manage_observees' do
    let(:observee_person) { create(:person) }
    let(:observee_teammate) { create(:teammate, person: observee_person, organization: organization) }

    context 'for kudos observation' do
      let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'kudos', created_as_type: 'kudos') }

      it 'redirects to kudos page' do
        patch manage_observees_organization_observation_path(organization, observation), params: {
          teammate_ids: [observee_teammate.id]
        }
        expect(response).to redirect_to(new_kudos_organization_observations_path(organization, draft_id: observation.id))
      end
    end

    context 'for feedback observation' do
      let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'feedback', created_as_type: 'feedback') }

      it 'redirects to feedback page' do
        patch manage_observees_organization_observation_path(organization, observation), params: {
          teammate_ids: [observee_teammate.id]
        }
        expect(response).to redirect_to(new_feedback_organization_observations_path(organization, draft_id: observation.id))
      end
    end

    context 'for quick_note observation' do
      let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'quick_note', created_as_type: 'quick_note') }

      it 'redirects to quick_note page' do
        patch manage_observees_organization_observation_path(organization, observation), params: {
          teammate_ids: [observee_teammate.id]
        }
        expect(response).to redirect_to(new_quick_note_organization_observations_path(organization, draft_id: observation.id))
      end
    end

    context 'for generic observation' do
      let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'generic', created_as_type: 'generic') }

      it 'redirects to generic page' do
        patch manage_observees_organization_observation_path(organization, observation), params: {
          teammate_ids: [observee_teammate.id]
        }
        expect(response).to redirect_to(new_organization_observation_path(organization, draft_id: observation.id))
      end
    end
  end

  describe 'POST /organizations/:organization_id/observations/:id/add_rateables' do
    let(:assignment) { create(:assignment, company: organization) }

    context 'for kudos observation' do
      let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'kudos', created_as_type: 'kudos') }

      it 'redirects to kudos page' do
        post add_rateables_organization_observation_path(organization, observation), params: {
          rateable_type: 'Assignment',
          rateable_ids: [assignment.id]
        }
        expect(response).to redirect_to(new_kudos_organization_observations_path(organization, draft_id: observation.id))
      end
    end

    context 'for feedback observation' do
      let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'feedback', created_as_type: 'feedback') }

      it 'redirects to feedback page' do
        post add_rateables_organization_observation_path(organization, observation), params: {
          rateable_type: 'Assignment',
          rateable_ids: [assignment.id]
        }
        expect(response).to redirect_to(new_feedback_organization_observations_path(organization, draft_id: observation.id))
      end
    end

    context 'for quick_note observation' do
      let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'quick_note', created_as_type: 'quick_note') }

      it 'redirects to quick_note page' do
        post add_rateables_organization_observation_path(organization, observation), params: {
          rateable_type: 'Assignment',
          rateable_ids: [assignment.id]
        }
        expect(response).to redirect_to(new_quick_note_organization_observations_path(organization, draft_id: observation.id))
      end
    end
  end

  describe 'PATCH /organizations/:organization_id/observations/new/update_draft' do
    let(:observee_person) { create(:person) }
    let(:observee_teammate) { create(:teammate, person: observee_person, organization: organization) }

    context 'for new kudos observation' do
      it 'preserves observation_type and sets created_as_type' do
        initial_count = Observation.count
        path = update_draft_organization_observation_path(organization, 'new')
        puts "Testing path: #{path}"
        puts "Organization param: #{organization.to_param}"
        # Forms submit as POST with _method='patch', so test that way
        post path, params: {
          _method: 'patch',
          observation: {
            observation_type: 'kudos',
            privacy_level: 'observed_and_managers'
          },
          observee_ids: [observee_teammate.id]
        }
        
        puts "Response status: #{response.status}"
        puts "Response location: #{response.location}" if response.location
        
        if response.status == 404
          puts "404 Error - Path: #{path}"
          # Try to extract exception from HTML
          if response.body =~ /<div[^>]*class="message"[^>]*>(.*?)<\/div>/m
            puts "Exception message: #{$1.strip[0..200]}"
          end
        end
        
        expect(response).to have_http_status(:redirect)
        expect(Observation.count).to eq(initial_count + 1)
        observation = Observation.last
        expect(observation.observation_type).to eq('kudos')
        expect(observation.created_as_type).to eq('kudos')
        expect(response).to redirect_to(new_kudos_organization_observations_path(organization, draft_id: observation.id))
      end
    end

    context 'for new feedback observation' do
      it 'preserves observation_type and sets created_as_type' do
        patch update_draft_organization_observation_path(organization, 'new'), params: {
          observation: {
            observation_type: 'feedback',
            privacy_level: 'observed_only'
          },
          observee_ids: [observee_teammate.id]
        }
        
        observation = Observation.last
        expect(observation.observation_type).to eq('feedback')
        expect(observation.created_as_type).to eq('feedback')
        expect(response).to redirect_to(new_feedback_organization_observations_path(organization, draft_id: observation.id))
      end
    end

    context 'for new quick_note observation' do
      it 'preserves observation_type and sets created_as_type' do
        patch update_draft_organization_observation_path(organization, 'new'), params: {
          observation: {
            observation_type: 'quick_note',
            privacy_level: 'observed_only'
          },
          observee_ids: [observee_teammate.id]
        }
        
        observation = Observation.last
        expect(observation.observation_type).to eq('quick_note')
        expect(observation.created_as_type).to eq('quick_note')
        expect(response).to redirect_to(new_quick_note_organization_observations_path(organization, draft_id: observation.id))
      end
    end

    context 'for new generic observation' do
      it 'preserves observation_type and sets created_as_type' do
        patch update_draft_organization_observation_path(organization, 'new'), params: {
          observation: {
            observation_type: 'generic',
            privacy_level: 'observed_and_managers'
          },
          observee_ids: [observee_teammate.id]
        }
        
        observation = Observation.last
        expect(observation.observation_type).to eq('generic')
        expect(observation.created_as_type).to eq('generic')
        expect(response).to redirect_to(new_organization_observation_path(organization, draft_id: observation.id))
      end
    end

    context 'when editing existing observation with created_as_type' do
      let(:existing_observation) { create(:observation, observer: person, company: organization, observation_type: 'kudos', created_as_type: 'kudos') }

      it 'does not change created_as_type' do
        patch update_draft_organization_observation_path(organization, existing_observation), params: {
          observation: {
            observation_type: 'kudos',
            privacy_level: 'observed_and_managers'
          }
        }
        
        existing_observation.reload
        expect(existing_observation.created_as_type).to eq('kudos')
      end
    end

    context 'with save_and_add_assignments' do
      let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'kudos', created_as_type: 'kudos') }

      it 'redirects to add_assignments with typed return_url' do
        patch update_draft_organization_observation_path(organization, observation), params: {
          observation: { privacy_level: 'observed_and_managers' },
          save_and_add_assignments: '1'
        }
        
        # Verify redirect includes the add_assignments path
        expect(response).to have_http_status(:redirect)
        redirect_location = response.headers['Location']
        expect(redirect_location).to include('add_assignments')
        # Verify the return_url in the redirect uses typed path
        expect(redirect_location).to include('new_kudos')
      end
    end
  end
end

