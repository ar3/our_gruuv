require 'rails_helper'

RSpec.describe Organizations::Asana::OauthController, type: :controller do
  let(:organization) { create(:organization, :company) }
  let(:manager) { create(:person, full_name: 'Manager Person') }
  let(:employee) { create(:person, full_name: 'Employee Person') }
  let(:manager_teammate) { create(:teammate, type: 'CompanyTeammate', person: manager, organization: organization, can_manage_employment: true) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:position_type) { create(:position_type, organization: organization) }
  let(:position_level) { create(:position_level, position_major_level: position_type.position_major_level) }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let(:employment_tenure) do
    employee_teammate.update!(first_employed_at: 1.year.ago)
    create(:employment_tenure, teammate: employee_teammate, company: organization, manager: manager, position: position)
  end

  before do
    manager_teammate.update!(first_employed_at: 1.year.ago)
    create(:employment_tenure, teammate: manager_teammate, company: organization, position: position, started_at: 1.year.ago, ended_at: nil)
    employment_tenure
    sign_in_as_teammate(manager, organization)
  end

  describe 'GET #authorize' do
    it 'redirects to Asana OAuth URL' do
      get :authorize, params: { 
        organization_id: organization.id, 
        person_id: employee.id,
        one_on_one_link_id: 'dummy' # Route requires this but we don't use it
      }
      
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include('app.asana.com/-/oauth_authorize')
      expect(response.location).to include('client_id=')
    end
  end

  describe 'GET #callback' do
    let(:oauth_code) { 'test_oauth_code' }
    let(:access_token) { 'test_access_token' }
    let(:asana_user_data) do
      {
        'gid' => '123456',
        'email' => 'user@example.com',
        'name' => 'Test User',
        'photo' => { 'image_128x128' => 'https://example.com/photo.jpg' }
      }
    end

    before do
      # Mock HTTP responses for token exchange
      token_response = double(
        body: double(to_s: { 'access_token' => access_token, 'refresh_token' => 'refresh_token', 'expires_in' => 3600 }.to_json)
      )
      allow(HTTP).to receive(:post).and_return(token_response)
      
      # Mock HTTP responses for user info
      user_response = double(
        body: double(to_s: { 'data' => asana_user_data }.to_json)
      )
      auth_double = double(get: user_response)
      allow(HTTP).to receive(:auth).and_return(auth_double)
    end

    it 'creates Asana identity on successful OAuth' do
      state = "#{organization.id}_#{employee_teammate.id}"
      
      expect {
        get :callback, params: { code: oauth_code, state: state }
      }.to change(TeammateIdentity, :count).by(1)
      
      identity = employee_teammate.reload.teammate_identities.asana.first
      expect(identity).to be_present
      expect(identity.uid).to eq('123456')
      expect(identity.email).to eq('user@example.com')
      expect(identity.name).to eq('Test User')
    end

    it 'updates existing Asana identity' do
      existing_identity = create(:teammate_identity, 
        teammate: employee_teammate, 
        provider: 'asana', 
        uid: '123456',
        email: 'old@example.com'
      )
      
      state = "#{organization.id}_#{employee_teammate.id}"
      
      get :callback, params: { code: oauth_code, state: state }
      
      existing_identity.reload
      expect(existing_identity.email).to eq('user@example.com')
      expect(existing_identity.name).to eq('Test User')
    end

    it 'handles OAuth errors gracefully' do
      allow(HTTP).to receive(:post).and_return(
        double(body: double(to_s: { 'error' => 'invalid_grant', 'error_description' => 'Invalid code' }.to_json))
      )
      
      state = "#{organization.id}_#{employee_teammate.id}"
      
      get :callback, params: { code: 'invalid_code', state: state }
      
      expect(response).to redirect_to(organization_person_one_on_one_link_path(organization, employee))
      expect(flash[:alert]).to include('Failed to connect Asana')
    end
  end
end

