require 'rails_helper'

RSpec.describe 'Organizations::Observations Mark as Journal', type: :request do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: company) }
  let(:draft_observation) do
    create(:observation, 
           observer: person, 
           company: company, 
           published_at: nil, 
           privacy_level: :observed_only,
           story: 'Test draft observation')
  end

  before do
    teammate # Ensure teammate is created
    sign_in_as_teammate_for_request(person, company)
    PaperTrail.enabled = false
  end

  after do
    PaperTrail.enabled = true
  end

  describe 'PATCH /organizations/:organization_id/observations/:id' do
    context 'when marking an observation as journal' do
      it 'updates the privacy level to observer_only' do
        expect(draft_observation.privacy_level).to eq('observed_only')
        
        patch "/organizations/#{company.to_param}/observations/#{draft_observation.id}/update_draft",
              params: { observation: { privacy_level: 'observer_only' } }
        
        expect(response).to have_http_status(:redirect)
        draft_observation.reload
        expect(draft_observation.privacy_level).to eq('observer_only')
      end

      it 'redirects appropriately after update' do
        patch "/organizations/#{company.to_param}/observations/#{draft_observation.id}/update_draft",
              params: { observation: { privacy_level: 'observer_only' } }
        
        # The update_draft action redirects to typed_observation_path_for or return_url
        expect(response).to have_http_status(:redirect)
      end

      it 'removes the observation from the Get Shit Done page' do
        # Create a draft observation that will appear on Get Shit Done
        draft = create(:observation, 
                       observer: person, 
                       company: company, 
                       published_at: nil, 
                       privacy_level: :observed_only,
                       story: 'Unique draft observation for removal test')
        
        # Verify it appears on Get Shit Done before marking as journal
        get "/organizations/#{company.to_param}/get_shit_done"
        expect(response.body).to include('Unique draft observation for removal test')
        
        # Mark as journal
        patch "/organizations/#{company.to_param}/observations/#{draft.id}/update_draft",
              params: { observation: { privacy_level: 'observer_only' } }
        
        expect(response).to have_http_status(:redirect)
        
        # Verify it no longer appears on Get Shit Done
        get "/organizations/#{company.to_param}/get_shit_done"
        expect(response.body).not_to include('Unique draft observation for removal test')
      end

      it 'requires the user to be the observer' do
        other_person = create(:person, email: "other#{SecureRandom.hex(4)}@example.com")
        sign_in_as_teammate_for_request(other_person, company)
        
        patch "/organizations/#{company.to_param}/observations/#{draft_observation.id}/update_draft",
              params: { observation: { privacy_level: 'observer_only' } }
        
        # Pundit will raise NotAuthorizedError which Rails will handle
        # The response could be 403 Forbidden or a redirect depending on Pundit configuration
        expect(response).to have_http_status(:forbidden).or have_http_status(:redirect)
        draft_observation.reload
        expect(draft_observation.privacy_level).to eq('observed_only')
      end
    end
  end
end
