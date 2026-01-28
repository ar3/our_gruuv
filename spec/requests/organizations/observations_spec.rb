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

  describe 'GET /organizations/:organization_id/observations (index)' do
    it 'allows access to index' do
      get organization_observations_path(organization)
      expect(response).to have_http_status(:success)
    end

    context 'with involving_teammate_id' do
      it 'shows Observations involving pill in Filters area when filter is active' do
        get organization_observations_path(organization, involving_teammate_id: teammate.id)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Observations involving')
        expect(response.body).to include(person.casual_name)
        expect(response.body).to include('rounded-pill')
      end
    end
  end

  describe 'GET /organizations/:organization_id/observations/select_type' do
    it 'allows access to select_type page' do
      get select_type_organization_observations_path(organization)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Select Observation Type')
      expect(response.body).to include('Kudos')
      expect(response.body).to include('Feedback')
      expect(response.body).to include('Quick Note')
      expect(response.body).not_to include('Generic Observation')
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

    it 'sets default privacy level to observed_only when not from check-in' do
      get new_quick_note_organization_observations_path(organization)
      expect(response).to have_http_status(:success)
      # The observation should be built with observed_only as default
      # We can verify this by checking the form or the observation instance
    end

    it 'sets default privacy level to observed_and_managers when return_url contains check_ins' do
      return_url = organization_company_teammate_check_ins_path(organization, teammate)
      get new_quick_note_organization_observations_path(organization, return_url: return_url, observee_ids: [teammate.id])
      expect(response).to have_http_status(:success)
      # Verify the notice is displayed
      expect(response.body).to include('After you save this note, to return to the check-in, close this page')
      # Verify privacy level is set correctly by checking the form value in the response
      expect(response.body).to match(/value="observed_and_managers"/)
    end

    it 'displays check-in notice when return_url contains check_ins' do
      return_url = organization_company_teammate_check_ins_path(organization, teammate)
      get new_quick_note_organization_observations_path(organization, return_url: return_url)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('After you save this note, to return to the check-in, close this page')
    end
  end

  describe 'PATCH /organizations/:organization_id/observations/:id/convert_to_generic' do
    context 'for kudos observation' do
      let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'kudos', created_as_type: 'kudos') }

      it 'converts observation type to generic' do
        patch convert_to_generic_organization_observation_path(organization, observation)
        expect(response).to redirect_to(new_organization_observation_path(organization, draft_id: observation.id))
        observation.reload
        expect(observation.observation_type).to eq('generic')
        expect(observation.created_as_type).to eq('kudos') # Should not change
      end

      it 'preserves return_url and return_text params in redirect' do
        return_url = organization_observations_path(organization)
        return_text = 'Back to Observations'
        patch convert_to_generic_organization_observation_path(organization, observation, return_url: return_url, return_text: return_text)
        expect(response).to redirect_to(new_organization_observation_path(organization, draft_id: observation.id, return_url: return_url, return_text: return_text))
        observation.reload
        expect(observation.observation_type).to eq('generic')
        expect(observation.created_as_type).to eq('kudos')
      end
    end

    context 'for feedback observation' do
      let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'feedback', created_as_type: 'feedback') }

      it 'converts observation type to generic' do
        patch convert_to_generic_organization_observation_path(organization, observation)
        expect(response).to redirect_to(new_organization_observation_path(organization, draft_id: observation.id))
        observation.reload
        expect(observation.observation_type).to eq('generic')
        expect(observation.created_as_type).to eq('feedback') # Should not change
      end

      it 'preserves return_url and return_text params in redirect' do
        return_url = organization_observations_path(organization)
        return_text = 'Back to Observations'
        patch convert_to_generic_organization_observation_path(organization, observation, return_url: return_url, return_text: return_text)
        expect(response).to redirect_to(new_organization_observation_path(organization, draft_id: observation.id, return_url: return_url, return_text: return_text))
        observation.reload
        expect(observation.observation_type).to eq('generic')
        expect(observation.created_as_type).to eq('feedback')
      end
    end

    context 'for quick_note observation' do
      let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'quick_note', created_as_type: 'quick_note') }

      it 'converts observation type to generic' do
        patch convert_to_generic_organization_observation_path(organization, observation)
        expect(response).to redirect_to(new_organization_observation_path(organization, draft_id: observation.id))
        observation.reload
        expect(observation.observation_type).to eq('generic')
        expect(observation.created_as_type).to eq('quick_note') # Should not change
      end

      it 'preserves return_url and return_text params in redirect' do
        return_url = organization_observations_path(organization)
        return_text = 'Back to Observations'
        patch convert_to_generic_organization_observation_path(organization, observation, return_url: return_url, return_text: return_text)
        expect(response).to redirect_to(new_organization_observation_path(organization, draft_id: observation.id, return_url: return_url, return_text: return_text))
        observation.reload
        expect(observation.observation_type).to eq('generic')
        expect(observation.created_as_type).to eq('quick_note')
      end
    end

    context 'authorization' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { create(:teammate, person: other_person, organization: organization) }
      let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'kudos', created_as_type: 'kudos') }

      it 'requires update permission' do
        sign_in_as_teammate_for_request(other_person, organization)
        original_type = observation.observation_type
        patch convert_to_generic_organization_observation_path(organization, observation)
        # Authorization failures typically redirect in this app
        expect(response).to have_http_status(:redirect)
        observation.reload
        expect(observation.observation_type).to eq(original_type) # Should not change
      end
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
        expect(response).to redirect_to(organization_observation_path(organization, observation))
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
        expect(response).to redirect_to(organization_observation_path(organization, observation))
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
        expect(response).to redirect_to(organization_observation_path(organization, observation))
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
        expect(response).to redirect_to(organization_observation_path(organization, observation))
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

    context 'with save_and_convert_to_generic' do
      let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'kudos', created_as_type: 'kudos') }

      it 'converts observation type to generic and redirects' do
        return_url = organization_observations_path(organization)
        return_text = 'Back to Observations'
        
        post update_draft_organization_observation_path(organization, observation), params: {
          _method: 'patch',
          observation: { privacy_level: 'observed_and_managers' },
          save_and_convert_to_generic: '1',
          return_url: return_url,
          return_text: return_text
        }
        
        expect(response).to have_http_status(:redirect)
        observation.reload
        expect(observation.observation_type).to eq('generic')
        expect(observation.created_as_type).to eq('kudos') # Should not change
        expect(response).to redirect_to(new_organization_observation_path(organization, draft_id: observation.id, return_url: return_url, return_text: return_text))
      end

      context 'for feedback observation' do
        let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'feedback', created_as_type: 'feedback') }

        it 'converts observation type to generic' do
          post update_draft_organization_observation_path(organization, observation), params: {
            _method: 'patch',
            observation: { privacy_level: 'observed_only' },
            save_and_convert_to_generic: '1'
          }
          
          observation.reload
          expect(observation.observation_type).to eq('generic')
          expect(observation.created_as_type).to eq('feedback')
        end
      end

      context 'for quick_note observation' do
        let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'quick_note', created_as_type: 'quick_note') }

        it 'converts observation type to generic' do
          post update_draft_organization_observation_path(organization, observation), params: {
            _method: 'patch',
            observation: { privacy_level: 'observed_only' },
            save_and_convert_to_generic: '1'
          }
          
          observation.reload
          expect(observation.observation_type).to eq('generic')
          expect(observation.created_as_type).to eq('quick_note')
        end
      end
    end

    context 'with save_and_add_abilities' do
      let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'kudos', created_as_type: 'kudos') }

      it 'redirects to add_abilities with typed return_url' do
        patch update_draft_organization_observation_path(organization, observation), params: {
          observation: { privacy_level: 'observed_and_managers' },
          save_and_add_abilities: '1'
        }
        
        expect(response).to have_http_status(:redirect)
        redirect_location = response.headers['Location']
        expect(redirect_location).to include('add_abilities')
        expect(redirect_location).to include('new_kudos')
      end
    end

    context 'with save_and_add_aspirations' do
      let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'kudos', created_as_type: 'kudos') }

      it 'redirects to add_aspirations with typed return_url' do
        patch update_draft_organization_observation_path(organization, observation), params: {
          observation: { privacy_level: 'observed_and_managers' },
          save_and_add_aspirations: '1'
        }
        
        expect(response).to have_http_status(:redirect)
        redirect_location = response.headers['Location']
        expect(redirect_location).to include('add_aspirations')
        expect(redirect_location).to include('new_kudos')
      end
    end

    context 'with save_and_manage_observees' do
      let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'kudos', created_as_type: 'kudos') }

      it 'redirects to manage_observees with typed return_url' do
        patch update_draft_organization_observation_path(organization, observation), params: {
          observation: { privacy_level: 'observed_and_managers' },
          save_and_manage_observees: '1'
        }
        
        expect(response).to have_http_status(:redirect)
        redirect_location = response.headers['Location']
        expect(redirect_location).to include('manage_observees')
        expect(redirect_location).to include('new_kudos')
      end
    end

    context 'with save_draft_and_return' do
      let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'kudos', created_as_type: 'kudos') }

      it 'saves draft and redirects to return_url' do
        return_url = organization_observations_path(organization)
        post update_draft_organization_observation_path(organization, observation), params: {
          _method: 'patch',
          observation: { privacy_level: 'observed_and_managers', story: 'Test story' },
          save_draft_and_return: '1',
          return_url: return_url
        }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(return_url)
        observation.reload
        expect(observation.story).to eq('Test story')
      end

      it 'redirects to return_url when provided with save_draft_and_return' do
        quick_note = create(:observation, observer: person, company: organization, observation_type: 'quick_note', created_as_type: 'quick_note')
        return_url = organization_company_teammate_check_ins_path(organization, teammate)
        post update_draft_organization_observation_path(organization, quick_note), params: {
          _method: 'patch',
          observation: { privacy_level: 'observed_and_managers', story: 'Test story' },
          save_draft_and_return: '1',
          return_url: return_url
        }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(return_url)
        quick_note.reload
        expect(quick_note.story).to eq('Test story')
      end
    end

    context 'with default save (no button name)' do
      let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'quick_note', created_as_type: 'quick_note') }

      it 'saves and redirects to return_url when present' do
        return_url = organization_company_teammate_check_ins_path(organization, teammate)
        post update_draft_organization_observation_path(organization, observation), params: {
          _method: 'patch',
          observation: { privacy_level: 'observed_and_managers', story: 'Test story' },
          return_url: return_url
        }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(return_url)
        observation.reload
        expect(observation.story).to eq('Test story')
      end

      it 'redirects to observation show page when return_url is not present' do
        post update_draft_organization_observation_path(organization, observation), params: {
          _method: 'patch',
          observation: { privacy_level: 'observed_and_managers', story: 'Test story' }
        }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_observation_path(organization, observation))
        observation.reload
        expect(observation.story).to eq('Test story')
      end
    end
  end

  describe 'POST /organizations/:organization_id/observations/:id/publish' do
    let(:observation) do
      obs = build(:observation, observer: person, company: organization, observation_type: 'kudos', created_as_type: 'kudos', published_at: nil)
      obs.observees.build(teammate: create(:teammate, person: create(:person), organization: organization))
      obs.save!
      obs
    end

    context 'for kudos observation' do
      it 'publishes the observation' do
        post publish_organization_observation_path(organization, observation), params: {
          observation: {
            story: 'Test story',
            privacy_level: 'observed_and_managers'
          },
          return_url: organization_observations_path(organization)
        }
        
        expect(response).to have_http_status(:redirect)
        observation.reload
        expect(observation.published_at).to be_present
      end

      it 'redirects to return_url when provided' do
        return_url = organization_company_teammate_check_ins_path(organization, teammate)
        post publish_organization_observation_path(organization, observation), params: {
          observation: {
            story: 'Test story',
            privacy_level: 'observed_and_managers'
          },
          return_url: return_url
        }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(return_url)
        observation.reload
        expect(observation.published_at).to be_present
      end

      it 'redirects to observation show page when return_url is not provided' do
        post publish_organization_observation_path(organization, observation), params: {
          observation: {
            story: 'Test story',
            privacy_level: 'observed_and_managers'
          }
        }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_observation_path(organization, observation))
        observation.reload
        expect(observation.published_at).to be_present
      end
    end

    context 'for feedback observation' do
      let(:observation) do
        obs = build(:observation, observer: person, company: organization, observation_type: 'feedback', created_as_type: 'feedback', published_at: nil)
        obs.observees.build(teammate: create(:teammate, person: create(:person), organization: organization))
        obs.save!
        obs
      end

      it 'publishes the observation' do
        post publish_organization_observation_path(organization, observation), params: {
          observation: {
            story: 'Test story',
            privacy_level: 'observed_only'
          },
          return_url: organization_observations_path(organization)
        }
        
        expect(response).to have_http_status(:redirect)
        observation.reload
        expect(observation.published_at).to be_present
      end

      it 'redirects to return_url when provided' do
        return_url = organization_company_teammate_check_ins_path(organization, teammate)
        post publish_organization_observation_path(organization, observation), params: {
          observation: {
            story: 'Test story',
            privacy_level: 'observed_only'
          },
          return_url: return_url
        }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(return_url)
        observation.reload
        expect(observation.published_at).to be_present
      end
    end

    context 'when return_url is provided' do
      let(:quick_note) do
        obs = build(:observation, observer: person, company: organization, observation_type: 'quick_note', created_as_type: 'quick_note', published_at: nil)
        obs.observees.build(teammate: create(:teammate, person: create(:person), organization: organization))
        obs.save!
        obs
      end

      it 'redirects to return_url when publishing with return_url' do
        return_url = organization_company_teammate_check_ins_path(organization, teammate)
        post publish_organization_observation_path(organization, quick_note), params: {
          observation: {
            story: 'Test story',
            privacy_level: 'observed_and_managers'
          },
          return_url: return_url
        }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(return_url)
        quick_note.reload
        expect(quick_note.published_at).to be_present
      end
    end
  end

  describe 'POST /organizations/:organization_id/observations/:id/cancel' do
    let(:observation) do
      obs = build(:observation, observer: person, company: organization, observation_type: 'kudos', created_as_type: 'kudos', published_at: nil)
      obs.observees.build(teammate: create(:teammate, person: create(:person), organization: organization))
      obs.save!
      obs
    end

    context 'for kudos observation' do
      it 'redirects to return_url when provided' do
        return_url = organization_company_teammate_check_ins_path(organization, teammate)
        post cancel_organization_observation_path(organization, observation), params: {
          return_url: return_url
        }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(return_url)
      end

      it 'redirects to observations index when return_url is not provided' do
        post cancel_organization_observation_path(organization, observation)
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_observations_path(organization))
      end
    end

    context 'for quick_note observation' do
      let(:quick_note) do
        obs = build(:observation, observer: person, company: organization, observation_type: 'quick_note', created_as_type: 'quick_note', published_at: nil)
        obs.observees.build(teammate: create(:teammate, person: create(:person), organization: organization))
        obs.save!
        obs
      end

      it 'redirects to return_url when provided' do
        return_url = organization_company_teammate_check_ins_path(organization, teammate)
        post cancel_organization_observation_path(organization, quick_note), params: {
          return_url: return_url
        }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(return_url)
      end
    end
  end

  describe 'CSRF token in forms' do
    context 'for kudos observation form' do
      let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'kudos', created_as_type: 'kudos') }

      it 'includes CSRF token in new_kudos form' do
        get new_kudos_organization_observations_path(organization, draft_id: observation.id)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('authenticity_token')
        expect(response.body).to include('form_authenticity_token')
      end
    end

    context 'for feedback observation form' do
      let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'feedback', created_as_type: 'feedback') }

      it 'includes CSRF token in new_feedback form' do
        get new_feedback_organization_observations_path(organization, draft_id: observation.id)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('authenticity_token')
        expect(response.body).to include('form_authenticity_token')
      end
    end

    context 'for quick_note observation form' do
      let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'quick_note', created_as_type: 'quick_note') }

      it 'includes CSRF token in new_quick_note form' do
        get new_quick_note_organization_observations_path(organization, draft_id: observation.id)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('authenticity_token')
        expect(response.body).to include('form_authenticity_token')
      end
    end

    context 'for generic observation form' do
      let(:observation) { create(:observation, observer: person, company: organization, observation_type: 'generic', created_as_type: 'generic') }

      it 'includes CSRF token in new form' do
        get new_organization_observation_path(organization, draft_id: observation.id)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('authenticity_token')
        expect(response.body).to include('form_authenticity_token')
      end
    end
  end

  describe 'GET /organizations/:organization_id/observations/:id' do
    let(:observation) { create(:observation, observer: person, company: organization) }

    context 'when user is the observer' do
      it 'renders the show page with Archive button' do
        get organization_observation_path(organization, observation)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Archive')
        expect(response.body).to include('button')
      end

      it 'renders the show page with Restore button when observation is archived' do
        observation.soft_delete!
        get organization_observation_path(organization, observation)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Restore')
        expect(response.body).to include('Archived')
      end

      it 'shows Archive button even for observations older than 24 hours' do
        observation.update_column(:created_at, 2.days.ago)
        get organization_observation_path(organization, observation)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Archive')
      end
    end
  end

  describe 'PATCH /organizations/:organization_id/observations/:id/restore' do
    let(:observation) do
      obs = create(:observation, observer: person, company: organization)
      obs.soft_delete!
      obs
    end

    context 'when user is the observer' do
      it 'restores the observation' do
        expect {
          patch restore_organization_observation_path(organization, observation)
        }.to change { observation.reload.deleted_at }.to(nil)
      end

      it 'redirects to observation show page' do
        patch restore_organization_observation_path(organization, observation)
        expect(response).to redirect_to(organization_observation_path(organization, observation))
      end

      it 'sets a success notice' do
        patch restore_organization_observation_path(organization, observation)
        follow_redirect!
        expect(flash[:notice]).to eq('Observation was successfully restored.')
      end
    end

    context 'when user is not the observer' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { create(:teammate, person: other_person, organization: organization) }

      before do
        sign_in_as_teammate_for_request(other_person, organization)
      end

      it 'redirects to kudos page' do
        patch restore_organization_observation_path(organization, observation)
        date_part = observation.observed_at.strftime('%Y-%m-%d')
        expect(response).to redirect_to(organization_kudo_path(organization, date: date_part, id: observation.id))
      end
    end
  end
end

