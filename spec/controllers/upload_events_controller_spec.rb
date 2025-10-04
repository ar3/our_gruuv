require 'rails_helper'

RSpec.describe UploadEventsController, type: :controller do
  let(:organization) { create(:organization) }
  let(:person) { create(:person, current_organization: organization) }
  let(:upload_event) { create(:upload_event, creator: person, initiator: person, organization: organization) }

  before do
    session[:current_person_id] = person.id
    allow(controller).to receive(:current_organization).and_return(organization)
    allow(controller).to receive(:current_person).and_return(person)
  end

  describe 'GET #index' do
    context 'when user has employment management permission' do
      before do
        allow(person).to receive(:can_manage_employment?).and_return(true)
        # Create an upload event to ensure the list is not empty
        create(:upload_event, creator: person, initiator: person, organization: organization)
      end

      it 'returns a successful response' do
        get :index, params: { organization_id: organization.id }
        expect(response).to be_successful
      end

      it 'assigns @upload_events' do
        get :index, params: { organization_id: organization.id }
        expect(assigns(:upload_events)).to be_present
      end
    end

    context 'when user lacks employment management permission' do
      before do
        allow(person).to receive(:can_manage_employment?).and_return(false)
      end

      it 'redirects to root path' do
        get :index, params: { organization_id: organization.id }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'GET #show' do
    it 'returns a successful response' do
      get :show, params: { organization_id: organization.id, id: upload_event.id }
      expect(response).to be_successful
    end

    it 'assigns @upload_event' do
      get :show, params: { organization_id: organization.id, id: upload_event.id }
      expect(assigns(:upload_event)).to be_a(UploadEvent::UploadAssignmentCheckins)
      expect(assigns(:upload_event).id).to eq(upload_event.id)
    end
  end

  describe 'GET #new' do
    context 'when user has employment management permission' do
      before do
        allow(person).to receive(:can_manage_employment?).and_return(true)
      end

      it 'redirects to index when no type parameter is provided' do
        get :new, params: { organization_id: organization.id }
        expect(response).to redirect_to(organization_upload_events_path(organization))
        expect(flash[:alert]).to eq('Please select an upload type from the dropdown.')
      end

      it 'assigns a new upload_event when type parameter is provided' do
        get :new, params: { organization_id: organization.id, upload_event: { type: 'UploadEvent::UploadAssignmentCheckins' } }
        expect(assigns(:upload_event)).to be_a_new(UploadEvent::UploadAssignmentCheckins)
      end
    end

    context 'when user lacks employment management permission' do
      before do
        allow(person).to receive(:can_manage_employment?).and_return(false)
      end

      it 'redirects to root path' do
        get :new, params: { organization_id: organization.id }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'POST #create' do
    let(:file) { fixture_file_upload('test.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') }
    let(:valid_params) { { organization_id: organization.id, upload_event: { file: file, type: 'UploadEvent::UploadAssignmentCheckins' } } }

    context 'when user has employment management permission' do
      before do
        allow(person).to receive(:can_manage_employment?).and_return(true)
      end

      context 'with valid file' do
        before do
          allow_any_instance_of(EmploymentDataUploadParser).to receive(:parse).and_return(true)
          allow_any_instance_of(EmploymentDataUploadParser).to receive(:preview_actions).and_return({ people: [] })
        end

        it 'creates a new upload event' do
          expect {
            post :create, params: valid_params
          }.to change(UploadEvent, :count).by(1)
        end

        it 'redirects to the upload event show page' do
          post :create, params: valid_params
          expect(response).to redirect_to(organization_upload_event_path(organization, assigns(:upload_event)))
        end

        it 'sets creator and initiator' do
          post :create, params: valid_params
          expect(assigns(:upload_event).creator).to eq(person)
          expect(assigns(:upload_event).initiator).to eq(person)
        end
      end

      context 'with invalid file type' do
        let(:invalid_file) { fixture_file_upload('test.txt', 'text/plain') }
        let(:invalid_params) { { organization_id: organization.id, upload_event: { file: invalid_file } } }

        it 'redirects back to index with error' do
          post :create, params: invalid_params
          expect(response).to redirect_to(organization_upload_events_path(organization))
        end
      end

      context 'when parsing fails' do
        before do
          allow_any_instance_of(EmploymentDataUploadParser).to receive(:parse).and_return(false)
          allow_any_instance_of(EmploymentDataUploadParser).to receive(:errors).and_return(['Invalid format'])
        end

        it 'redirects back to index with error' do
          post :create, params: valid_params
          expect(response).to redirect_to(organization_upload_events_path(organization))
        end
      end
    end

    context 'when user lacks employment management permission' do
      before do
        allow(person).to receive(:can_manage_employment?).and_return(false)
      end

      it 'redirects to root path' do
        post :create, params: valid_params
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when upload event can be destroyed' do
      before do
        allow(upload_event).to receive(:can_destroy?).and_return(true)
      end

      it 'destroys the upload event' do
        expect {
          delete :destroy, params: { organization_id: organization.id, id: upload_event.id }
        }.to change(UploadEvent, :count).by(-1)
      end

      it 'redirects to index' do
        delete :destroy, params: { organization_id: organization.id, id: upload_event.id }
        expect(response).to redirect_to(organization_upload_events_path(organization))
      end
    end

    context 'when upload event cannot be destroyed' do
      before do
        allow_any_instance_of(UploadEvent).to receive(:can_destroy?).and_return(false)
      end

      it 'redirects to show with error' do
        delete :destroy, params: { organization_id: organization.id, id: upload_event.id }
        expect(response).to redirect_to(organization_upload_event_path(organization, upload_event))
        expect(flash[:alert]).to eq('Cannot delete this upload.')
      end
    end
  end

  describe 'POST #process_upload' do
    context 'when upload event can be processed' do
      before do
        allow(person).to receive(:can_manage_employment?).and_return(true)
        allow(upload_event).to receive(:can_process?).and_return(true)
        allow(EmploymentDataUploadProcessorJob).to receive(:perform_and_get_result).and_return(true)
      end

              it 'processes the upload inline' do
          expect(EmploymentDataUploadProcessorJob).to receive(:perform_and_get_result).with(upload_event.id, organization.id).and_return(true)
          post :process_upload, params: { organization_id: organization.id, id: upload_event.id }
        end

      it 'redirects to show with success message' do
        post :process_upload, params: { organization_id: organization.id, id: upload_event.id }
        expect(response).to redirect_to(organization_upload_event_path(organization, upload_event))
      end
    end

    context 'when upload event cannot be processed' do
      before do
        allow(person).to receive(:can_manage_employment?).and_return(true)
        upload_event.update!(status: 'completed') # Completed uploads cannot be processed
      end

      it 'redirects to show with error' do
        post :process_upload, params: { organization_id: organization.id, id: upload_event.id }
        expect(response).to redirect_to(organization_upload_event_path(organization, upload_event))
        expect(flash[:alert]).to eq('This upload cannot be processed.')
      end
    end

    context 'when user has employment management permission' do
      before do
        allow(person).to receive(:can_manage_employment?).and_return(true)
      end

      it 'processes upload when upload event can be processed' do
        expect(EmploymentDataUploadProcessorJob).to receive(:perform_and_get_result).with(upload_event.id, organization.id).and_return(true)

        post :process_upload, params: { organization_id: organization.id, id: upload_event.id }

        expect(response).to redirect_to(organization_upload_event_path(organization, upload_event))
        expect(flash[:notice]).to eq('Upload processed successfully!')
      end

      it 'filters preview actions based on selected items' do
        # Set up preview actions with some data
        upload_event.update!(
          preview_actions: {
            'people' => [
              { 'row' => 1, 'name' => 'John Doe' },
              { 'row' => 2, 'name' => 'Jane Smith' }
            ],
            'assignments' => [
              { 'row' => 1, 'title' => 'Engineer' },
              { 'row' => 2, 'title' => 'Manager' }
            ]
          }
        )

        expect(EmploymentDataUploadProcessorJob).to receive(:perform_and_get_result).with(upload_event.id, organization.id).and_return(true)

        # Process with only some items selected
        post :process_upload, params: {
          organization_id: organization.id,
          id: upload_event.id,
          selected_people: ['1'],
          selected_assignments: ['2']
        }

        # Check that the preview actions were filtered
        upload_event.reload
        expect(upload_event.preview_actions['people'].length).to eq(1)
        expect(upload_event.preview_actions['people'].first['row']).to eq(1)
        expect(upload_event.preview_actions['assignments'].length).to eq(1)
        expect(upload_event.preview_actions['assignments'].first['row']).to eq(2)
      end
    end

    context 'when user lacks employment management permission' do
      before do
        allow(person).to receive(:can_manage_employment?).and_return(false)
      end

      it 'redirects to root path' do
        post :process_upload, params: { organization_id: organization.id, id: upload_event.id }
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
