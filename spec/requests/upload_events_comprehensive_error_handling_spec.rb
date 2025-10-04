require 'rails_helper'

RSpec.describe 'UploadEventsController comprehensive error handling', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:file) { fixture_file_upload('test.csv', 'text/csv') }
  
  before do
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(person).to receive(:can_manage_employment?).and_return(true)
  end

  context 'error handling - no silent failures' do
    it 'explicitly handles missing type parameter' do
      params = {
        organization_id: organization.id,
        upload_event: {
          file: file
          # type is missing
        }
      }
      
      post organization_upload_events_path(organization), params: params
      
      expect(response).to redirect_to(organization_upload_events_path(organization))
      expect(flash[:alert]).to include('Type can\'t be blank')
    end

    it 'explicitly handles missing upload_event params' do
      params = {
        organization_id: organization.id
      }
      
      post organization_upload_events_path(organization), params: params
      
      expect(response).to redirect_to(organization_upload_events_path(organization))
      expect(flash[:alert]).to include('Type can\'t be blank')
    end

    it 'explicitly handles invalid type parameter' do
      params = {
        organization_id: organization.id,
        upload_event: {
          type: 'InvalidType',
          file: file
        }
      }
      
      post organization_upload_events_path(organization), params: params
      
      expect(response).to redirect_to(organization_upload_events_path(organization))
      expect(flash[:alert]).to include('Type is not included in the list')
    end

    it 'explicitly handles missing file parameter' do
      params = {
        organization_id: organization.id,
        upload_event: {
          type: 'UploadEvent::UploadEmployees'
          # file is missing
        }
      }
      
      post organization_upload_events_path(organization), params: params
      
      # Should render the form again with validation errors
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  context 'successful flow' do
    before do
      # Mock the parser to return success
      allow_any_instance_of(UnassignedEmployeeUploadParser).to receive(:parse).and_return(true)
      allow_any_instance_of(UnassignedEmployeeUploadParser).to receive(:enhanced_preview_actions).and_return({ unassigned_employees: [] })
    end

    it 'successfully creates upload event with all required parameters' do
      params = {
        organization_id: organization.id,
        upload_event: {
          type: 'UploadEvent::UploadEmployees',
          file: file
        }
      }
      
      expect {
        post organization_upload_events_path(organization), params: params
      }.to change(UploadEvent, :count).by(1)
      
      expect(response).to redirect_to(organization_upload_event_path(organization, UploadEvent.last))
      expect(flash[:notice]).to eq('Upload created successfully. Please review the preview before processing.')
    end
  end
end
