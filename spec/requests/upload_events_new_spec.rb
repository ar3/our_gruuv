require 'rails_helper'

RSpec.describe 'UploadEvents#new', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  
  before do
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(person).to receive(:can_manage_employment?).and_return(true)
  end

  it 'handles requests without type parameter gracefully' do
    expect {
      get new_organization_upload_event_path(organization)
    }.not_to raise_error
  end

  it 'redirects to index when no type parameter is provided' do
    get new_organization_upload_event_path(organization)
    expect(response).to redirect_to(organization_upload_events_path(organization))
    expect(flash[:alert]).to eq('Please select an upload type from the dropdown.')
  end

  it 'renders the new upload event page with UploadEmployees type' do
    get new_organization_upload_event_path(organization, upload_event: {type: 'UploadEvent::UploadEmployees'})
    expect(response).to be_successful
  end

  it 'renders the new upload event page with UploadAssignmentCheckins type' do
    get new_organization_upload_event_path(organization, upload_event: {type: 'UploadEvent::UploadAssignmentCheckins'})
    expect(response).to be_successful
  end
end
