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
          expect(csv.headers).to include(
            'First Name', 'Middle Name', 'Last Name', 'Suffix', 'Preferred Name', 'External Title',
            'Email', 'Slack User Name',
            'Last PageVisit Created At', 'First PageVisit Created At', 'PageVisit Count',
            'Last Position Finalized Check-In', 'Last Assignment Finalized Check-In', 'Last Aspiration Finalized Check-In',
            'Number of Milestones Attained', 'Manager Email',
            'Number of Published Observations (as Observee)', '1:1 Document Link', 'Public Page Link',
            'Active Assignments'
          )
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
          # Enable PaperTrail for assignments CSV tests
          PaperTrail.enabled = true
        end

        after do
          # Disable PaperTrail after tests
          PaperTrail.enabled = false
        end

        it 'allows download' do
          get :download, params: { organization_id: organization.id, type: 'assignments' }
          expect(response).to have_http_status(:success)
          expect(response.content_type).to include('text/csv')
        end

        it 'generates CSV with correct headers' do
          get :download, params: { organization_id: organization.id, type: 'assignments' }
          csv = CSV.parse(response.body, headers: true)
          expect(csv.headers).to include('Title', 'Tagline', 'Department', 'Positions', 'Milestones', 'Outcomes', 'Version', 'Changes Count', 'Public URL')
        end

        it 'includes assignment data with department in CSV' do
          department = create(:organization, :department, parent: organization)
          assignment = create(:assignment, company: organization, department: department, title: 'Test Assignment', semantic_version: '1.0.0')
          # Make 3 updates to create version history
          assignment.update!(semantic_version: '1.1.0')
          assignment.update!(semantic_version: '1.2.0')
          assignment.update!(semantic_version: '2.1.3')
          
          get :download, params: { organization_id: organization.id, type: 'assignments' }
          csv = CSV.parse(response.body, headers: true)
          
          row = csv.find { |r| r['Title'] == 'Test Assignment' }
          expect(row).to be_present
          expect(row['Department']).to eq(department.display_name)
          expect(row['Version']).to eq('2.1.3')
          expect(row['Changes Count']).to eq('3') # 3 updates after creation
        end

        it 'uses company name when no department' do
          assignment = create(:assignment, company: organization, department: nil, title: 'No Dept Assignment')
          
          get :download, params: { organization_id: organization.id, type: 'assignments' }
          csv = CSV.parse(response.body, headers: true)
          
          row = csv.find { |r| r['Title'] == 'No Dept Assignment' }
          expect(row).to be_present
          expect(row['Department']).to eq(organization.display_name)
        end

        it 'includes positions data in CSV' do
          assignment = create(:assignment, company: organization, title: 'Position Test')
          position_major_level = create(:position_major_level)
          title = create(:title, organization: organization, external_title: 'Software Engineer', position_major_level: position_major_level)
          position_level = create(:position_level, position_major_level: position_major_level)
          position = create(:position, title: title, position_level: position_level)
          create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required', min_estimated_energy: 10, max_estimated_energy: 20)
          
          get :download, params: { organization_id: organization.id, type: 'assignments' }
          csv = CSV.parse(response.body, headers: true)
          
          row = csv.find { |r| r['Title'] == 'Position Test' }
          expect(row).to be_present
          expect(row['Positions']).to eq("Software Engineer - #{position_level.level} (required, 10%-20%)")
        end

        it 'includes multiple positions separated by newlines' do
          assignment = create(:assignment, company: organization, title: 'Multi Position Test')
          position_major_level1 = create(:position_major_level)
          position_major_level2 = create(:position_major_level)
          title1 = create(:title, organization: organization, external_title: 'Backend Engineer', position_major_level: position_major_level1)
          title2 = create(:title, organization: organization, external_title: 'Frontend Engineer', position_major_level: position_major_level2)
          position_level1 = create(:position_level, level: '1.0', position_major_level: position_major_level1)
          position_level2 = create(:position_level, level: '3.0', position_major_level: position_major_level2)
          position1 = create(:position, title: title1, position_level: position_level1)
          position2 = create(:position, title: title2, position_level: position_level2)
          create(:position_assignment, position: position1, assignment: assignment, assignment_type: 'required', min_estimated_energy: 10, max_estimated_energy: 20)
          create(:position_assignment, position: position2, assignment: assignment, assignment_type: 'suggested', min_estimated_energy: 5, max_estimated_energy: 15)
          
          get :download, params: { organization_id: organization.id, type: 'assignments' }
          csv = CSV.parse(response.body, headers: true)
          
          row = csv.find { |r| r['Title'] == 'Multi Position Test' }
          expect(row).to be_present
          expect(row['Positions']).to include("Backend Engineer - 1.0 (required, 10%-20%)")
          expect(row['Positions']).to include("Frontend Engineer - 3.0 (suggested, 5%-15%)")
          expect(row['Positions'].split("\n").size).to eq(2)
        end

        it 'handles positions with missing energy values' do
          assignment = create(:assignment, company: organization, title: 'Energy Edge Cases')
          position_major_level = create(:position_major_level)
          title = create(:title, organization: organization, external_title: 'Software Engineer', position_major_level: position_major_level)
          position_level = create(:position_level, level: '1.0', position_major_level: position_major_level)
          position = create(:position, title: title, position_level: position_level)
          
          # No energy values
          create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required', min_estimated_energy: nil, max_estimated_energy: nil)
          
          get :download, params: { organization_id: organization.id, type: 'assignments' }
          csv = CSV.parse(response.body, headers: true)
          
          row = csv.find { |r| r['Title'] == 'Energy Edge Cases' }
          expect(row).to be_present
          expect(row['Positions']).to eq("Software Engineer - 1.0 (required)")
        end

        it 'includes milestones data in CSV' do
          assignment = create(:assignment, company: organization, title: 'Milestone Test')
          ability = create(:ability, organization: organization, name: 'Ruby Programming')
          create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 3)
          
          get :download, params: { organization_id: organization.id, type: 'assignments' }
          csv = CSV.parse(response.body, headers: true)
          
          row = csv.find { |r| r['Title'] == 'Milestone Test' }
          expect(row).to be_present
          expect(row['Milestones']).to eq('Ruby Programming - Milestone 3')
        end

        it 'includes multiple milestones separated by newlines' do
          assignment = create(:assignment, company: organization, title: 'Multi Milestone Test')
          ability1 = create(:ability, organization: organization, name: 'Ruby Programming')
          ability2 = create(:ability, organization: organization, name: 'JavaScript')
          create(:assignment_ability, assignment: assignment, ability: ability1, milestone_level: 2)
          create(:assignment_ability, assignment: assignment, ability: ability2, milestone_level: 4)
          
          get :download, params: { organization_id: organization.id, type: 'assignments' }
          csv = CSV.parse(response.body, headers: true)
          
          row = csv.find { |r| r['Title'] == 'Multi Milestone Test' }
          expect(row).to be_present
          expect(row['Milestones']).to include('Ruby Programming - Milestone 2')
          expect(row['Milestones']).to include('JavaScript - Milestone 4')
          expect(row['Milestones'].split("\n").size).to eq(2)
        end

        it 'includes outcomes data in CSV' do
          assignment = create(:assignment, company: organization, title: 'Outcome Test')
          create(:assignment_outcome, assignment: assignment, description: 'Reduce bugs by 50%')
          create(:assignment_outcome, assignment: assignment, description: 'Improve performance')
          
          get :download, params: { organization_id: organization.id, type: 'assignments' }
          csv = CSV.parse(response.body, headers: true)
          
          row = csv.find { |r| r['Title'] == 'Outcome Test' }
          expect(row).to be_present
          expect(row['Outcomes']).to include('Reduce bugs by 50%')
          expect(row['Outcomes']).to include('Improve performance')
          expect(row['Outcomes'].split("\n").size).to eq(2)
        end

        it 'calculates changes count correctly based on PaperTrail versions' do
          assignment = create(:assignment, company: organization, title: 'Version Test', semantic_version: '1.0.0')
          # Make 5 updates to test version counting
          5.times do |i|
            assignment.update!(tagline: "Updated tagline #{i + 1}")
          end
          
          get :download, params: { organization_id: organization.id, type: 'assignments' }
          csv = CSV.parse(response.body, headers: true)
          
          row = csv.find { |r| r['Title'] == 'Version Test' }
          expect(row).to be_present
          expect(row['Changes Count']).to eq('5') # 5 updates after creation
        end

        it 'includes public URL for assignment' do
          assignment = create(:assignment, company: organization, title: 'Public URL Test')
          
          get :download, params: { organization_id: organization.id, type: 'assignments' }
          csv = CSV.parse(response.body, headers: true)
          
          row = csv.find { |r| r['Title'] == 'Public URL Test' }
          expect(row).to be_present
          # The controller generates the URL using the configured default_url_options
          # So we generate it the same way to match
          expected_url = begin
            Rails.application.routes.url_helpers.organization_public_maap_assignment_url(
              assignment.company,
              assignment
            )
          rescue
            Rails.application.routes.url_helpers.organization_public_maap_assignment_path(
              assignment.company,
              assignment
            )
          end
          expect(row['Public URL']).to eq(expected_url)
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
          expect(csv.headers).to include(
            'Name', 'Description', 'Organization', 'Assignments',
            'Milestone 1 Description', 'Milestone 2 Description', 'Milestone 3 Description',
            'Milestone 4 Description', 'Milestone 5 Description'
          )
        end

        it 'includes assignments with milestone requirements in CSV' do
          ability = create(:ability, organization: organization, name: 'Test Ability')
          assignment1 = create(:assignment, company: organization, title: 'Assignment One')
          assignment2 = create(:assignment, company: organization, title: 'Assignment Two')
          create(:assignment_ability, :same_organization, assignment: assignment1, ability: ability, milestone_level: 2)
          create(:assignment_ability, :same_organization, assignment: assignment2, ability: ability, milestone_level: 3)
          
          get :download, params: { organization_id: organization.id, type: 'abilities' }
          csv = CSV.parse(response.body, headers: true)
          row = csv.find { |r| r['Name'] == 'Test Ability' }
          
          expect(row).to be_present
          expect(row['Assignments']).to include('Assignment One - Milestone 2')
          expect(row['Assignments']).to include('Assignment Two - Milestone 3')
        end

        it 'handles abilities with no assignments' do
          ability = create(:ability, organization: organization, name: 'Test Ability')
          
          get :download, params: { organization_id: organization.id, type: 'abilities' }
          csv = CSV.parse(response.body, headers: true)
          row = csv.find { |r| r['Name'] == 'Test Ability' }
          
          expect(row).to be_present
          expect(row['Assignments']).to eq('')
        end

        it 'includes milestone descriptions in CSV' do
          ability = create(:ability,
            organization: organization,
            name: 'Test Ability',
            milestone_1_description: 'Basic understanding',
            milestone_2_description: 'Intermediate skills',
            milestone_3_description: 'Advanced proficiency',
            milestone_4_description: 'Expert level',
            milestone_5_description: 'Master level'
          )
          
          get :download, params: { organization_id: organization.id, type: 'abilities' }
          csv = CSV.parse(response.body, headers: true)
          row = csv.find { |r| r['Name'] == 'Test Ability' }
          
          expect(row).to be_present
          expect(row['Milestone 1 Description']).to eq('Basic understanding')
          expect(row['Milestone 2 Description']).to eq('Intermediate skills')
          expect(row['Milestone 3 Description']).to eq('Advanced proficiency')
          expect(row['Milestone 4 Description']).to eq('Expert level')
          expect(row['Milestone 5 Description']).to eq('Master level')
        end

        it 'handles abilities with partial milestone descriptions' do
          ability = create(:ability,
            organization: organization,
            name: 'Test Ability',
            milestone_1_description: 'Basic understanding',
            milestone_2_description: 'Intermediate skills'
          )
          
          get :download, params: { organization_id: organization.id, type: 'abilities' }
          csv = CSV.parse(response.body, headers: true)
          row = csv.find { |r| r['Name'] == 'Test Ability' }
          
          expect(row).to be_present
          expect(row['Milestone 1 Description']).to eq('Basic understanding')
          expect(row['Milestone 2 Description']).to eq('Intermediate skills')
          expect(row['Milestone 3 Description']).to eq('')
          expect(row['Milestone 4 Description']).to eq('')
          expect(row['Milestone 5 Description']).to eq('')
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
          expect(csv.headers).to include(
            'External Title', 'Level', 'Company', 'Department', 'Semantic Version', 'Created At', 'Updated At',
            'Public Position URL', 'Number of Active Employment Tenures', 'Assignments', 'Version Count',
            'Title', 'Position Summary', 'Seats', 'Other Uploads'
          )
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

    context 'when S3 upload succeeds' do
      before do
        employed_teammate
        sign_in_as_teammate(employed_person, organization)
        allow_any_instance_of(S3::CsvUploader).to receive(:upload).and_return({
          s3_key: 'bulk-downloads/123/assignments/test.csv',
          s3_url: 'https://bucket.s3.amazonaws.com/bulk-downloads/123/assignments/test.csv'
        })
      end

      it 'creates a BulkDownload record' do
        expect {
          get :download, params: { organization_id: organization.id, type: 'assignments' }
        }.to change(BulkDownload, :count).by(1)
        
        bulk_download = BulkDownload.last
        expect(bulk_download.company_id).to eq(organization.id)
        expect(bulk_download.downloaded_by_id).to eq(employed_teammate.id)
        expect(bulk_download.download_type).to eq('assignments')
        expect(bulk_download.s3_key).to be_present
        expect(bulk_download.s3_url).to be_present
        expect(bulk_download.filename).to be_present
        expect(bulk_download.file_size).to be_present
      end
    end

    context 'when S3 upload fails' do
      before do
        employed_teammate
        sign_in_as_teammate(employed_person, organization)
        allow_any_instance_of(S3::CsvUploader).to receive(:upload).and_raise(StandardError.new('S3 Error'))
      end

      it 'still sends CSV to user' do
        get :download, params: { organization_id: organization.id, type: 'assignments' }
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('text/csv')
      end

      it 'does not create a BulkDownload record' do
        expect {
          get :download, params: { organization_id: organization.id, type: 'assignments' }
        }.not_to change(BulkDownload, :count)
      end
    end

    context 'when downloading seats CSV' do
      before do
        employed_teammate
        sign_in_as_teammate(employed_person, organization)
        allow_any_instance_of(S3::CsvUploader).to receive(:upload).and_return({
          s3_key: 'bulk-downloads/123/seats/test.csv',
          s3_url: 'https://bucket.s3.amazonaws.com/bulk-downloads/123/seats/test.csv'
        })
      end

      it 'allows download' do
        get :download, params: { organization_id: organization.id, type: 'seats' }
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('text/csv')
      end
    end

    context 'when downloading titles CSV' do
      before do
        employed_teammate
        sign_in_as_teammate(employed_person, organization)
        allow_any_instance_of(S3::CsvUploader).to receive(:upload).and_return({
          s3_key: 'bulk-downloads/123/titles/test.csv',
          s3_url: 'https://bucket.s3.amazonaws.com/bulk-downloads/123/titles/test.csv'
        })
      end

      it 'allows download' do
        get :download, params: { organization_id: organization.id, type: 'titles' }
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('text/csv')
      end
    end

    context 'when downloading departments_and_teams CSV' do
      before do
        employed_teammate
        sign_in_as_teammate(employed_person, organization)
        allow_any_instance_of(S3::CsvUploader).to receive(:upload).and_return({
          s3_key: 'bulk-downloads/123/departments_and_teams/test.csv',
          s3_url: 'https://bucket.s3.amazonaws.com/bulk-downloads/123/departments_and_teams/test.csv'
        })
      end

      it 'allows download' do
        get :download, params: { organization_id: organization.id, type: 'departments_and_teams' }
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('text/csv')
      end
    end
  end

  describe 'GET #show' do
    let(:bulk_download) do
      teammate = CompanyTeammate.find(employed_teammate.id)
      create(:bulk_download, :assignments, company: organization, downloaded_by: teammate)
    end

    before do
      employed_teammate
      sign_in_as_teammate(employed_person, organization)
    end

    it 'allows access to show page' do
      get :show, params: { organization_id: organization.id, id: 'assignments' }
      expect(response).to have_http_status(:success)
    end

    it 'loads bulk downloads for the specified type' do
      bulk_download
      teammate = CompanyTeammate.find(employed_teammate.id)
      other_download = create(:bulk_download, :abilities, company: organization, downloaded_by: teammate)
      
      get :show, params: { organization_id: organization.id, id: 'assignments' }
      
      expect(assigns(:bulk_downloads)).to include(bulk_download)
      expect(assigns(:bulk_downloads)).not_to include(other_download)
    end
  end

  describe 'GET #download_file' do
    let(:bulk_download) { create(:bulk_download, :assignments, company: organization, downloaded_by: employed_teammate.reload) }
    let(:other_teammate) { create(:company_teammate, organization: organization) }
    let(:other_bulk_download) { create(:bulk_download, :assignments, company: organization, downloaded_by: other_teammate) }

    context 'when user can download any file (og_admin or can_manage_employment)' do
      before do
        employment_teammate
        sign_in_as_teammate(employment_person, organization)
        allow_any_instance_of(S3::CsvUploader).to receive(:download).and_return('CSV content')
      end

      it 'allows download of own file' do
        teammate = CompanyTeammate.find(employment_teammate.id)
        own_download = create(:bulk_download, :assignments, company: organization, downloaded_by: teammate)
        get :download_file, params: { organization_id: organization.id, id: own_download.id }
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('text/csv')
      end

      it 'allows download of other user\'s file' do
        get :download_file, params: { organization_id: organization.id, id: other_bulk_download.id }
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('text/csv')
      end
    end

    context 'when user can only download own file' do
      before do
        employed_teammate
        sign_in_as_teammate(employed_person, organization)
        allow_any_instance_of(S3::CsvUploader).to receive(:download).and_return('CSV content')
      end

      it 'allows download of own file' do
        teammate = CompanyTeammate.find(employed_teammate.id)
        own_download = create(:bulk_download, :assignments, company: organization, downloaded_by: teammate)
        get :download_file, params: { organization_id: organization.id, id: own_download.id }
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('text/csv')
      end

      it 'denies download of other user\'s file' do
        get :download_file, params: { organization_id: organization.id, id: other_bulk_download.id }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end

