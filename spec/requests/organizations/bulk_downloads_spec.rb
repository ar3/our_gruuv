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

        it 'includes teammate data in CSV' do
          person = create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com')
          CompanyTeammate.create!(person: person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
          get download_organization_bulk_downloads_path(organization, type: 'company_teammates')
          expect(response.body).to include('John')
          expect(response.body).to include('Doe')
          expect(response.body).to include('john@example.com')
        end

        it 'includes PageVisit data in CSV' do
          person = create(:person, email: 'test@example.com')
          teammate = CompanyTeammate.create!(person: person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
          create(:page_visit, person: person, url: '/page1', created_at: 3.days.ago)
          create(:page_visit, person: person, url: '/page2', created_at: 1.day.ago)
          
          get download_organization_bulk_downloads_path(organization, type: 'company_teammates')
          csv = CSV.parse(response.body, headers: true)
          row = csv.find { |r| r['Email'] == 'test@example.com' }
          expect(row).to be_present
          expect(row['PageVisit Count']).to eq('2')
        end

        it 'includes Slack user name when teammate has Slack identity' do
          person = create(:person, email: 'slack@example.com')
          teammate = CompanyTeammate.create!(person: person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
          create(:teammate_identity, teammate: teammate, provider: 'slack', name: 'Slack User', uid: 'U12345')
          
          get download_organization_bulk_downloads_path(organization, type: 'company_teammates')
          csv = CSV.parse(response.body, headers: true)
          row = csv.find { |r| r['Email'] == 'slack@example.com' }
          expect(row).to be_present
          expect(row['Slack User Name']).to eq('Slack User')
        end

        it 'includes manager email when teammate has a manager' do
          manager_person = create(:person, email: 'manager@example.com')
          manager_teammate = CompanyTeammate.create!(person: manager_person, organization: organization, first_employed_at: 2.months.ago, last_terminated_at: nil)
          
          person = create(:person, email: 'employee@example.com')
          teammate = CompanyTeammate.create!(person: person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
          
          position_major_level = create(:position_major_level)
          title = create(:title, organization: organization, position_major_level: position_major_level)
          position_level = create(:position_level, position_major_level: position_major_level)
          position = create(:position, title: title, position_level: position_level)
          
          create(:employment_tenure, teammate: teammate, company: organization, position: position, manager_teammate: manager_teammate, started_at: 1.month.ago)
          
          get download_organization_bulk_downloads_path(organization, type: 'company_teammates')
          csv = CSV.parse(response.body, headers: true)
          row = csv.find { |r| r['Email'] == 'employee@example.com' }
          expect(row).to be_present
          expect(row['Manager Email']).to eq('manager@example.com')
        end

        it 'includes milestone count' do
          person = create(:person, email: 'milestone@example.com')
          teammate = CompanyTeammate.create!(person: person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
          ability = create(:ability, organization: organization)
          create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 1, attained_at: 1.week.ago)
          create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 2, attained_at: 3.days.ago)
          
          get download_organization_bulk_downloads_path(organization, type: 'company_teammates')
          csv = CSV.parse(response.body, headers: true)
          row = csv.find { |r| r['Email'] == 'milestone@example.com' }
          expect(row).to be_present
          expect(row['Number of Milestones Attained']).to eq('2')
        end

        it 'includes published observations count' do
          observer_person = create(:person, email: 'observer@example.com')
          observer_teammate = CompanyTeammate.create!(person: observer_person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
          
          person = create(:person, email: 'observee@example.com')
          teammate = CompanyTeammate.create!(person: person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
          
          observation1 = create(:observation, observer: observer_person, company: organization, published_at: 1.week.ago)
          observation2 = create(:observation, observer: observer_person, company: organization, published_at: 3.days.ago)
          create(:observee, observation: observation1, teammate: teammate)
          create(:observee, observation: observation2, teammate: teammate)
          
          get download_organization_bulk_downloads_path(organization, type: 'company_teammates')
          csv = CSV.parse(response.body, headers: true)
          row = csv.find { |r| r['Email'] == 'observee@example.com' }
          expect(row).to be_present
          expect(row['Number of Published Observations (as Observee)']).to eq('2')
        end

        it 'includes 1:1 document link' do
          person = create(:person, email: 'oneonone@example.com')
          teammate = CompanyTeammate.create!(person: person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
          create(:one_on_one_link, teammate: teammate, url: 'https://docs.google.com/document/d/123')
          
          get download_organization_bulk_downloads_path(organization, type: 'company_teammates')
          csv = CSV.parse(response.body, headers: true)
          row = csv.find { |r| r['Email'] == 'oneonone@example.com' }
          expect(row).to be_present
          expect(row['1:1 Document Link']).to eq('https://docs.google.com/document/d/123')
        end

        it 'includes public page link' do
          person = create(:person, email: 'public@example.com')
          CompanyTeammate.create!(person: person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
          
          get download_organization_bulk_downloads_path(organization, type: 'company_teammates')
          csv = CSV.parse(response.body, headers: true)
          row = csv.find { |r| r['Email'] == 'public@example.com' }
          expect(row).to be_present
          expect(row['Public Page Link']).to include("/people/#{person.id}/public")
        end

        it 'includes last finalized check-in dates' do
          person = create(:person, email: 'checkin@example.com')
          teammate = CompanyTeammate.create!(person: person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
          
          position_major_level = create(:position_major_level)
          title = create(:title, organization: organization, position_major_level: position_major_level)
          position_level = create(:position_level, position_major_level: position_major_level)
          position = create(:position, title: title, position_level: position_level)
          employment_tenure = create(:employment_tenure, teammate: teammate, company: organization, position: position, started_at: 1.month.ago)
          
          assignment = create(:assignment, company: organization)
          aspiration = create(:aspiration, organization: organization)
          
          position_check_in = create(:position_check_in, :closed, teammate: teammate, employment_tenure: employment_tenure, official_check_in_completed_at: 5.days.ago)
          assignment_check_in = create(:assignment_check_in, :officially_completed, teammate: teammate, assignment: assignment, official_check_in_completed_at: 3.days.ago)
          aspiration_check_in = create(:aspiration_check_in, :finalized, teammate: teammate, aspiration: aspiration, official_check_in_completed_at: 1.day.ago)
          
          get download_organization_bulk_downloads_path(organization, type: 'company_teammates')
          csv = CSV.parse(response.body, headers: true)
          row = csv.find { |r| r['Email'] == 'checkin@example.com' }
          expect(row).to be_present
          expect(row['Last Position Finalized Check-In']).to be_present
          expect(row['Last Assignment Finalized Check-In']).to be_present
          expect(row['Last Aspiration Finalized Check-In']).to be_present
        end

        it 'includes active assignments in CSV' do
          person = create(:person, email: 'assignments@example.com')
          teammate = CompanyTeammate.create!(person: person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
          
          assignment1 = create(:assignment, company: organization, title: 'Assignment One')
          assignment2 = create(:assignment, company: organization, title: 'Assignment Two')
          
          # Create active assignment tenures
          create(:assignment_tenure, teammate: teammate, assignment: assignment1, started_at: 2.weeks.ago, ended_at: nil, anticipated_energy_percentage: 50, official_rating: 'Exceeds')
          create(:assignment_tenure, teammate: teammate, assignment: assignment2, started_at: 1.week.ago, ended_at: nil, anticipated_energy_percentage: 30)
          
          get download_organization_bulk_downloads_path(organization, type: 'company_teammates')
          csv = CSV.parse(response.body, headers: true)
          row = csv.find { |r| r['Email'] == 'assignments@example.com' }
          expect(row).to be_present
          
          active_assignments = row['Active Assignments']
          expect(active_assignments).to include('Assignment One')
          expect(active_assignments).to include('Assignment Two')
          expect(active_assignments).to include('ID:')
          expect(active_assignments).to include('Started:')
          expect(active_assignments).to include('Energy: 50%')
          expect(active_assignments).to include('Energy: 30%')
          expect(active_assignments).to include('Rating: Exceeds')
          expect(active_assignments.split("\n").size).to eq(2)
        end

        it 'excludes inactive assignment tenures from active assignments' do
          person = create(:person, email: 'inactive@example.com')
          teammate = CompanyTeammate.create!(person: person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
          
          assignment1 = create(:assignment, company: organization, title: 'Active Assignment')
          assignment2 = create(:assignment, company: organization, title: 'Inactive Assignment')
          
          # Create one active and one inactive tenure
          create(:assignment_tenure, teammate: teammate, assignment: assignment1, started_at: 2.weeks.ago, ended_at: nil, anticipated_energy_percentage: 50)
          create(:assignment_tenure, teammate: teammate, assignment: assignment2, started_at: 1.month.ago, ended_at: 1.week.ago, anticipated_energy_percentage: 30)
          
          get download_organization_bulk_downloads_path(organization, type: 'company_teammates')
          csv = CSV.parse(response.body, headers: true)
          row = csv.find { |r| r['Email'] == 'inactive@example.com' }
          expect(row).to be_present
          
          active_assignments = row['Active Assignments']
          expect(active_assignments).to include('Active Assignment')
          expect(active_assignments).not_to include('Inactive Assignment')
          expect(active_assignments.split("\n").size).to eq(1)
        end

        it 'excludes assignment tenures with zero energy from active assignments' do
          person = create(:person, email: 'zeroenergy@example.com')
          teammate = CompanyTeammate.create!(person: person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
          
          assignment1 = create(:assignment, company: organization, title: 'Active Assignment')
          assignment2 = create(:assignment, company: organization, title: 'Zero Energy Assignment')
          
          # Create one with energy and one without
          create(:assignment_tenure, teammate: teammate, assignment: assignment1, started_at: 2.weeks.ago, ended_at: nil, anticipated_energy_percentage: 50)
          create(:assignment_tenure, teammate: teammate, assignment: assignment2, started_at: 1.week.ago, ended_at: nil, anticipated_energy_percentage: 0)
          
          get download_organization_bulk_downloads_path(organization, type: 'company_teammates')
          csv = CSV.parse(response.body, headers: true)
          row = csv.find { |r| r['Email'] == 'zeroenergy@example.com' }
          expect(row).to be_present
          
          active_assignments = row['Active Assignments']
          expect(active_assignments).to include('Active Assignment')
          expect(active_assignments).not_to include('Zero Energy Assignment')
          expect(active_assignments.split("\n").size).to eq(1)
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

        it 'includes public assignment URL in CSV' do
          assignment = create(:assignment, company: organization, title: 'Test Assignment')
          get download_organization_bulk_downloads_path(organization, type: 'assignments')
          csv = CSV.parse(response.body, headers: true)
          row = csv.find { |r| r['Title'] == 'Test Assignment' }
          expect(row).to be_present
          # Try to get full URL, fallback to path if URL generation fails (e.g., in test environment)
          expected_url = begin
            Rails.application.routes.url_helpers.organization_public_maap_assignment_url(organization, assignment)
          rescue
            Rails.application.routes.url_helpers.organization_public_maap_assignment_path(organization, assignment)
          end
          expect(row['Public URL']).to eq(expected_url)
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
          expect(csv.headers).to include(
            'Name', 'Description', 'Organization', 'Assignments',
            'Milestone 1 Description', 'Milestone 2 Description', 'Milestone 3 Description',
            'Milestone 4 Description', 'Milestone 5 Description'
          )
        end

        it 'includes ability data in CSV' do
          ability = create(:ability, organization: organization, name: 'Test Ability')
          get download_organization_bulk_downloads_path(organization, type: 'abilities')
          expect(response.body).to include('Test Ability')
        end

        it 'includes assignments with milestone requirements in CSV' do
          ability = create(:ability, organization: organization, name: 'Test Ability')
          assignment1 = create(:assignment, company: organization, title: 'Assignment One')
          assignment2 = create(:assignment, company: organization, title: 'Assignment Two')
          create(:assignment_ability, :same_organization, assignment: assignment1, ability: ability, milestone_level: 2)
          create(:assignment_ability, :same_organization, assignment: assignment2, ability: ability, milestone_level: 3)
          
          get download_organization_bulk_downloads_path(organization, type: 'abilities')
          csv = CSV.parse(response.body, headers: true)
          row = csv.find { |r| r['Name'] == 'Test Ability' }
          
          expect(row).to be_present
          expect(row['Assignments']).to include('Assignment One - Milestone 2')
          expect(row['Assignments']).to include('Assignment Two - Milestone 3')
        end

        it 'handles abilities with no assignments' do
          ability = create(:ability, organization: organization, name: 'Test Ability')
          
          get download_organization_bulk_downloads_path(organization, type: 'abilities')
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
          
          get download_organization_bulk_downloads_path(organization, type: 'abilities')
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
          
          get download_organization_bulk_downloads_path(organization, type: 'abilities')
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
          expect(csv.headers).to include(
            'External Title', 'Level', 'Company', 'Semantic Version', 'Created At', 'Updated At',
            'Public Position URL', 'Number of Active Employment Tenures', 'Assignments', 'Version Count',
            'Position Type Summary', 'Position Summary', 'Seats'
          )
        end

        it 'includes position data in CSV' do
          position_major_level = create(:position_major_level)
          position_level = create(:position_level, position_major_level: position_major_level)
          title = create(:title, organization: organization, position_major_level: position_major_level, external_title: 'Software Engineer')
          position = create(:position, title: title, position_level: position_level)
          get download_organization_bulk_downloads_path(organization, type: 'positions')
          expect(response.body).to include('Software Engineer')
        end

        it 'includes public position URL in CSV' do
          position_major_level = create(:position_major_level)
          position_level = create(:position_level, position_major_level: position_major_level)
          title = create(:title, organization: organization, position_major_level: position_major_level, external_title: 'Software Engineer')
          position = create(:position, title: title, position_level: position_level)
          get download_organization_bulk_downloads_path(organization, type: 'positions')
          csv = CSV.parse(response.body, headers: true)
          row = csv.first
          # Try to get full URL, fallback to path if URL generation fails (e.g., in test environment)
          expected_url = begin
            Rails.application.routes.url_helpers.organization_public_maap_position_url(organization, position)
          rescue
            Rails.application.routes.url_helpers.organization_public_maap_position_path(organization, position)
          end
          expect(row['Public Position URL']).to eq(expected_url)
        end

        it 'includes number of active employment tenures in CSV' do
          position_major_level = create(:position_major_level)
          position_level = create(:position_level, position_major_level: position_major_level)
          title = create(:title, organization: organization, position_major_level: position_major_level, external_title: 'Software Engineer')
          position = create(:position, title: title, position_level: position_level)
          teammate1 = create(:teammate, organization: organization)
          teammate2 = create(:teammate, organization: organization)
          # Build employment tenures and set position after factory callback runs
          et1 = build(:employment_tenure, teammate: teammate1, company: organization, started_at: 1.month.ago, ended_at: nil)
          et1.position = position
          et1.save!
          et2 = build(:employment_tenure, teammate: teammate2, company: organization, started_at: 2.months.ago, ended_at: nil)
          et2.position = position
          et2.save!
          et3 = build(:employment_tenure, teammate: teammate1, company: organization, started_at: 1.year.ago, ended_at: 6.months.ago)
          et3.position = position
          et3.save!
          get download_organization_bulk_downloads_path(organization, type: 'positions')
          csv = CSV.parse(response.body, headers: true)
          row = csv.first
          expect(row['Number of Active Employment Tenures']).to eq('2')
        end

        it 'includes assignments with min, max, and type in CSV' do
          position_major_level = create(:position_major_level)
          position_level = create(:position_level, position_major_level: position_major_level)
          title = create(:title, organization: organization, position_major_level: position_major_level, external_title: 'Software Engineer')
          position = create(:position, title: title, position_level: position_level)
          assignment1 = create(:assignment, company: organization, title: 'Assignment 1')
          assignment2 = create(:assignment, company: organization, title: 'Assignment 2')
          create(:position_assignment, position: position, assignment: assignment1, assignment_type: 'required', min_estimated_energy: 20, max_estimated_energy: 40)
          create(:position_assignment, position: position, assignment: assignment2, assignment_type: 'suggested', min_estimated_energy: 10, max_estimated_energy: 30)
          get download_organization_bulk_downloads_path(organization, type: 'positions')
          csv = CSV.parse(response.body, headers: true)
          row = csv.first
          assignments = row['Assignments']
          expect(assignments).to include('Assignment 1 (required, 20%-40%)')
          expect(assignments).to include('Assignment 2 (suggested, 10%-30%)')
          expect(assignments.split("\n").size).to eq(2)
        end

        it 'handles assignments with missing energy values in CSV' do
          position_major_level = create(:position_major_level)
          position_level = create(:position_level, position_major_level: position_major_level)
          title = create(:title, organization: organization, position_major_level: position_major_level, external_title: 'Software Engineer')
          position = create(:position, title: title, position_level: position_level)
          assignment = create(:assignment, company: organization, title: 'Assignment No Energy')
          create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required', min_estimated_energy: nil, max_estimated_energy: nil)
          get download_organization_bulk_downloads_path(organization, type: 'positions')
          csv = CSV.parse(response.body, headers: true)
          row = csv.first
          assignments = row['Assignments']
          expect(assignments).to eq('Assignment No Energy (required)')
        end

        it 'includes version count in CSV' do
          # Enable PaperTrail for this test
          PaperTrail.enabled = true
          position_major_level = create(:position_major_level)
          position_level = create(:position_level, position_major_level: position_major_level)
          title = create(:title, organization: organization, position_major_level: position_major_level, external_title: 'Software Engineer')
          position = create(:position, title: title, position_level: position_level)
          # PaperTrail creates a version on create, so we should have at least 1
          position.update!(semantic_version: '1.1.0') # This will create another version
          get download_organization_bulk_downloads_path(organization, type: 'positions')
          csv = CSV.parse(response.body, headers: true)
          row = csv.first
          expect(row['Version Count'].to_i).to be >= 2
          PaperTrail.enabled = false
        end

        it 'includes position type summary and position summary in separate columns' do
          position_major_level = create(:position_major_level)
          position_level = create(:position_level, position_major_level: position_major_level)
          title = create(:title, organization: organization, position_major_level: position_major_level, external_title: 'Software Engineer', position_summary: 'Base position type summary')
          position = create(:position, title: title, position_level: position_level, position_summary: 'Position-specific summary')
          get download_organization_bulk_downloads_path(organization, type: 'positions')
          csv = CSV.parse(response.body, headers: true)
          row = csv.first
          expect(row['Position Type Summary']).to eq('Base position type summary')
          expect(row['Position Summary']).to eq('Position-specific summary')
        end

        it 'includes seats in CSV' do
          position_major_level = create(:position_major_level)
          position_level = create(:position_level, position_major_level: position_major_level)
          title = create(:title, organization: organization, position_major_level: position_major_level, external_title: 'Software Engineer')
          position = create(:position, title: title, position_level: position_level)
          seat1 = create(:seat, title: title, seat_needed_by: Date.new(2024, 1, 1))
          seat2 = create(:seat, title: title, seat_needed_by: Date.new(2024, 6, 1))
          get download_organization_bulk_downloads_path(organization, type: 'positions')
          csv = CSV.parse(response.body, headers: true)
          row = csv.first
          seats = row['Seats']
          expect(seats).to include(seat1.display_name)
          expect(seats).to include(seat2.display_name)
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

