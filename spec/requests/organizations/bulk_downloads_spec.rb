require 'rails_helper'

RSpec.describe 'Organizations::BulkDownloads', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:admin) { create(:person, :admin) }
  let(:employment_person) { create(:person) }
  let(:employed_person) { create(:person) }
  let(:no_permission_person) { create(:person) }
  
  let(:person_teammate) { create(:teammate, person: person, organization: organization) }
  let(:admin_teammate) { create(:teammate, person: admin, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil) }
  let(:employment_teammate) { create(:teammate, person: employment_person, organization: organization, can_manage_employment: true, first_employed_at: 1.month.ago, last_terminated_at: nil) }
  let(:employed_teammate) { create(:teammate, person: employed_person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil) }
  let(:no_permission_teammate) { create(:teammate, person: no_permission_person, organization: organization, first_employed_at: nil, last_terminated_at: nil) }

  before do
    # Temporarily disable PaperTrail for request tests to avoid controller_info issues
    PaperTrail.enabled = false
  end

  after do
    # Re-enable PaperTrail after tests
    PaperTrail.enabled = true
  end

  describe 'GET /organizations/:organization_id/bulk_downloads' do
    context 'when user is any teammate' do
      before do
        person_teammate
        sign_in_as_teammate_for_request(person, organization)
      end

      it 'allows access to index page' do
        get organization_bulk_downloads_path(organization)
        expect(response).to have_http_status(:success)
      end

      it 'allows access using to_param format (id-slug)' do
        get "/organizations/#{organization.to_param}/bulk_downloads"
        expect(response).to have_http_status(:success)
      end

      it 'displays the bulk downloads page' do
        get organization_bulk_downloads_path(organization)
        expect(response.body).to include('Bulk Downloads')
        expect(response.body).to include('Company Teammates')
        expect(response.body).to include('All Assignments')
        expect(response.body).to include('All Abilities')
        expect(response.body).to include('All Positions')
      end

      it 'displays the bulk downloads page using to_param format' do
        get "/organizations/#{organization.to_param}/bulk_downloads"
        expect(response.body).to include('Bulk Downloads')
        expect(response.body).to include('Company Teammates')
        expect(response.body).to include('All Assignments')
        expect(response.body).to include('All Abilities')
        expect(response.body).to include('All Positions')
      end
    end
  end

  describe 'GET /organizations/:organization_id/bulk_downloads/download' do
    context 'when downloading company_teammates CSV' do
      context 'with manage_employment permission' do
        before do
          employment_teammate
          sign_in_as_teammate_for_request(employment_person, organization)
        end

        it 'allows download' do
          get download_organization_bulk_downloads_path(organization, type: 'company_teammates')
          expect(response).to have_http_status(:success)
          expect(response.content_type).to include('text/csv')
        end

        it 'generates CSV with correct headers' do
          get download_organization_bulk_downloads_path(organization, type: 'company_teammates')
          csv = CSV.parse(response.body, headers: true)
          expect(csv.headers).to include('First Name', 'Middle Name', 'Last Name', 'Suffix', 'Preferred Name', 'External Title')
        end

        it 'includes teammate data in CSV' do
          person = create(:person, first_name: 'John', last_name: 'Doe')
          CompanyTeammate.create!(person: person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
          get download_organization_bulk_downloads_path(organization, type: 'company_teammates')
          expect(response.body).to include('John')
          expect(response.body).to include('Doe')
        end
      end

      context 'without manage_employment permission' do
        before do
          no_permission_teammate
          sign_in_as_teammate_for_request(no_permission_person, organization)
        end

        it 'denies download' do
          get download_organization_bulk_downloads_path(organization, type: 'company_teammates')
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(root_path)
        end
      end
    end

    context 'when downloading assignments CSV' do
      context 'with active teammate (employed)' do
        before do
          employed_teammate
          sign_in_as_teammate_for_request(employed_person, organization)
        end

        it 'allows download' do
          get download_organization_bulk_downloads_path(organization, type: 'assignments')
          expect(response).to have_http_status(:success)
          expect(response.content_type).to include('text/csv')
        end

        it 'generates CSV with correct headers' do
          get download_organization_bulk_downloads_path(organization, type: 'assignments')
          csv = CSV.parse(response.body, headers: true)
          expect(csv.headers).to include('Title', 'Tagline', 'Department', 'Positions', 'Milestones', 'Outcomes', 'Version', 'Changes Count', 'Public URL')
        end

        it 'includes assignment data in CSV' do
          assignment = create(:assignment, company: organization, title: 'Test Assignment')
          get download_organization_bulk_downloads_path(organization, type: 'assignments')
          expect(response.body).to include('Test Assignment')
        end
      end

      context 'without active teammate (not employed)' do
        before do
          no_permission_teammate
          sign_in_as_teammate_for_request(no_permission_person, organization)
        end

        it 'denies download' do
          get download_organization_bulk_downloads_path(organization, type: 'assignments')
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(root_path)
        end
      end
    end

    context 'when downloading abilities CSV' do
      context 'with active teammate (employed)' do
        before do
          employed_teammate
          sign_in_as_teammate_for_request(employed_person, organization)
        end

        it 'allows download' do
          get download_organization_bulk_downloads_path(organization, type: 'abilities')
          expect(response).to have_http_status(:success)
          expect(response.content_type).to include('text/csv')
        end

        it 'generates CSV with correct headers' do
          get download_organization_bulk_downloads_path(organization, type: 'abilities')
          csv = CSV.parse(response.body, headers: true)
          expect(csv.headers).to include('Name', 'Description', 'Organization')
        end

        it 'includes ability data in CSV' do
          ability = create(:ability, organization: organization, name: 'Test Ability')
          get download_organization_bulk_downloads_path(organization, type: 'abilities')
          expect(response.body).to include('Test Ability')
        end
      end

      context 'without active teammate (not employed)' do
        before do
          no_permission_teammate
          sign_in_as_teammate_for_request(no_permission_person, organization)
        end

        it 'denies download' do
          get download_organization_bulk_downloads_path(organization, type: 'abilities')
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(root_path)
        end
      end
    end

    context 'when downloading positions CSV' do
      context 'with active teammate (employed)' do
        before do
          employed_teammate
          sign_in_as_teammate_for_request(employed_person, organization)
        end

        it 'allows download' do
          get download_organization_bulk_downloads_path(organization, type: 'positions')
          expect(response).to have_http_status(:success)
          expect(response.content_type).to include('text/csv')
        end

        it 'generates CSV with correct headers' do
          get download_organization_bulk_downloads_path(organization, type: 'positions')
          csv = CSV.parse(response.body, headers: true)
          expect(csv.headers).to include('External Title', 'Level', 'Company')
        end

        it 'includes position data in CSV' do
          position_major_level = create(:position_major_level)
          position_level = create(:position_level, position_major_level: position_major_level)
          position_type = create(:position_type, organization: organization, position_major_level: position_major_level, external_title: 'Software Engineer')
          position = create(:position, position_type: position_type, position_level: position_level)
          get download_organization_bulk_downloads_path(organization, type: 'positions')
          expect(response.body).to include('Software Engineer')
        end
      end

      context 'without active teammate (not employed)' do
        before do
          no_permission_teammate
          sign_in_as_teammate_for_request(no_permission_person, organization)
        end

        it 'denies download' do
          get download_organization_bulk_downloads_path(organization, type: 'positions')
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(root_path)
        end
      end
    end

    context 'with invalid type' do
      before do
        employed_teammate
        sign_in_as_teammate_for_request(employed_person, organization)
      end

      it 'returns not found' do
        get download_organization_bulk_downloads_path(organization, type: 'invalid_type')
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when user is admin' do
      before do
        admin_teammate
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'allows all downloads' do
        get download_organization_bulk_downloads_path(organization, type: 'company_teammates')
        expect(response).to have_http_status(:success)
        
        get download_organization_bulk_downloads_path(organization, type: 'assignments')
        expect(response).to have_http_status(:success)
        
        get download_organization_bulk_downloads_path(organization, type: 'abilities')
        expect(response).to have_http_status(:success)
        
        get download_organization_bulk_downloads_path(organization, type: 'positions')
        expect(response).to have_http_status(:success)
      end
    end
  end
end

