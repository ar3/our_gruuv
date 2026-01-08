require 'rails_helper'

RSpec.describe Organizations::BulkDownloadsController, type: :controller do
  let(:person) { create(:person) }
  let(:organization) { create(:organization, :company) }
  let(:employment_person) { create(:person) }
  let(:employed_person) { create(:person) }
  let(:no_permission_person) { create(:person) }
  
  let(:employment_teammate) { create(:teammate, person: employment_person, organization: organization, can_manage_employment: true, first_employed_at: 1.month.ago, last_terminated_at: nil) }
  let(:employed_teammate) { create(:teammate, person: employed_person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil) }
  let(:no_permission_teammate) { create(:teammate, person: no_permission_person, organization: organization, first_employed_at: nil, last_terminated_at: nil) }

  describe 'GET #index' do
    context 'when user is any teammate' do
      before do
        no_permission_teammate
        sign_in_as_teammate(no_permission_person, organization)
      end

      it 'allows access to index page' do
        get :index, params: { organization_id: organization.id }
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'GET #download' do
    context 'when downloading company_teammates CSV' do
      context 'with manage_employment permission' do
        before do
          employment_teammate
          sign_in_as_teammate(employment_person, organization)
        end

        it 'allows download' do
          get :download, params: { organization_id: organization.id, type: 'company_teammates' }
          expect(response).to have_http_status(:success)
          expect(response.content_type).to include('text/csv')
        end

        it 'generates CSV with correct headers' do
          get :download, params: { organization_id: organization.id, type: 'company_teammates' }
          csv = CSV.parse(response.body, headers: true)
          expect(csv.headers).to include('First Name', 'Middle Name', 'Last Name', 'Suffix', 'Preferred Name', 'External Title')
        end
      end

      context 'without manage_employment permission' do
        before do
          no_permission_teammate
          sign_in_as_teammate(no_permission_person, organization)
        end

        it 'denies download' do
          get :download, params: { organization_id: organization.id, type: 'company_teammates' }
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(root_path)
        end
      end
    end

    context 'when downloading assignments CSV' do
      context 'with active teammate (employed)' do
        before do
          employed_teammate
          sign_in_as_teammate(employed_person, organization)
        end

        it 'allows download' do
          get :download, params: { organization_id: organization.id, type: 'assignments' }
          expect(response).to have_http_status(:success)
          expect(response.content_type).to include('text/csv')
        end

        it 'generates CSV with correct headers' do
          get :download, params: { organization_id: organization.id, type: 'assignments' }
          csv = CSV.parse(response.body, headers: true)
          expect(csv.headers).to include('Title', 'Tagline', 'Company', 'Department')
        end
      end

      context 'without active teammate (not employed)' do
        before do
          no_permission_teammate
          sign_in_as_teammate(no_permission_person, organization)
        end

        it 'denies download' do
          get :download, params: { organization_id: organization.id, type: 'assignments' }
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(root_path)
        end
      end
    end

    context 'when downloading abilities CSV' do
      context 'with active teammate (employed)' do
        before do
          employed_teammate
          sign_in_as_teammate(employed_person, organization)
        end

        it 'allows download' do
          get :download, params: { organization_id: organization.id, type: 'abilities' }
          expect(response).to have_http_status(:success)
          expect(response.content_type).to include('text/csv')
        end

        it 'generates CSV with correct headers' do
          get :download, params: { organization_id: organization.id, type: 'abilities' }
          csv = CSV.parse(response.body, headers: true)
          expect(csv.headers).to include('Name', 'Description', 'Organization')
        end
      end

      context 'without active teammate (not employed)' do
        before do
          no_permission_teammate
          sign_in_as_teammate(no_permission_person, organization)
        end

        it 'denies download' do
          get :download, params: { organization_id: organization.id, type: 'abilities' }
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(root_path)
        end
      end
    end

    context 'when downloading positions CSV' do
      context 'with active teammate (employed)' do
        before do
          employed_teammate
          sign_in_as_teammate(employed_person, organization)
        end

        it 'allows download' do
          get :download, params: { organization_id: organization.id, type: 'positions' }
          expect(response).to have_http_status(:success)
          expect(response.content_type).to include('text/csv')
        end

        it 'generates CSV with correct headers' do
          get :download, params: { organization_id: organization.id, type: 'positions' }
          csv = CSV.parse(response.body, headers: true)
          expect(csv.headers).to include('External Title', 'Level', 'Company')
        end
      end

      context 'without active teammate (not employed)' do
        before do
          no_permission_teammate
          sign_in_as_teammate(no_permission_person, organization)
        end

        it 'denies download' do
          get :download, params: { organization_id: organization.id, type: 'positions' }
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(root_path)
        end
      end
    end

    context 'with invalid type' do
      before do
        employed_teammate
        sign_in_as_teammate(employed_person, organization)
      end

      it 'returns not found' do
        get :download, params: { organization_id: organization.id, type: 'invalid_type' }
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end

