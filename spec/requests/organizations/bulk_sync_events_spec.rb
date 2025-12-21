require 'rails_helper'

RSpec.describe 'Organizations::BulkSyncEvents', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:admin) { create(:person, :admin) }
  let(:maap_manager) { create(:person) }
  
  let(:person_teammate) { create(:teammate, person: person, organization: organization) }
  let(:admin_teammate) { create(:teammate, person: admin, organization: organization) }
  let(:maap_teammate) { create(:teammate, person: maap_manager, organization: organization, can_manage_maap: true) }
  let(:employment_teammate) { create(:teammate, person: create(:person), organization: organization, can_manage_employment: true) }

  before do
    # Temporarily disable PaperTrail for request tests to avoid controller_info issues
    PaperTrail.enabled = false
  end

  after do
    # Re-enable PaperTrail after tests
    PaperTrail.enabled = true
  end

  describe 'GET /organizations/:organization_id/bulk_sync_events/:id' do
    context 'with UploadAssignmentsAndAbilities event' do
      let(:assignment) { create(:assignment, company: organization, title: 'Test Assignment') }
      let(:ability) { create(:ability, organization: organization, name: 'Test Ability') }
      let(:position_major_level) { create(:position_major_level) }
      let(:position_level) { create(:position_level, position_major_level: position_major_level) }
      let(:position_type) { create(:position_type, organization: organization, position_major_level: position_major_level) }
      let(:position) { create(:position, position_type: position_type, position_level: position_level) }
      
      let(:bulk_sync_event) do
        create(:upload_assignments_and_abilities,
          organization: organization,
          creator: person,
          initiator: person,
          status: 'completed',
          results: {
            'successes' => [
              {
                'type' => 'ability',
                'id' => ability.id,
                'name' => ability.name,
                'action' => 'created',
                'row' => 2
              },
              {
                'type' => 'assignment',
                'id' => assignment.id,
                'title' => assignment.title,
                'action' => 'created',
                'row' => 3
              },
              {
                'type' => 'assignment_ability',
                'id' => 1,
                'assignment_id' => assignment.id,
                'ability_id' => ability.id,
                'assignment_title' => assignment.title,
                'ability_name' => ability.name,
                'action' => 'created',
                'row' => 4
              },
              {
                'type' => 'position_assignment',
                'id' => 1,
                'position_id' => position.id,
                'assignment_id' => assignment.id,
                'assignment_title' => assignment.title,
                'position_title' => position.display_name,
                'action' => 'created',
                'row' => 5
              }
            ],
            'failures' => []
          }
        )
      end

      context 'when user has can_manage_maap permission' do
        before do
          maap_teammate
          sign_in_as_teammate_for_request(maap_manager, organization)
        end

        it 'allows access to show page' do
          get organization_bulk_sync_event_path(organization, bulk_sync_event)
          expect(response).to have_http_status(:success)
        end

        it 'displays processing results' do
          get organization_bulk_sync_event_path(organization, bulk_sync_event)
          expect(response.body).to include('Processing Results')
          expect(response.body).to include('Successful Operations')
        end

        it 'displays ability results with link' do
          get organization_bulk_sync_event_path(organization, bulk_sync_event)
          expect(response.body).to include(ability.name)
          # Check for the path in the HTML - it should contain the organization slug and ability id
          expect(response.body).to match(%r{/organizations/[^/]+/abilities/#{ability.id}})
        end

        it 'displays assignment results with link' do
          get organization_bulk_sync_event_path(organization, bulk_sync_event)
          expect(response.body).to include(assignment.title)
          # Check for the path in the HTML - it should contain the organization slug and assignment id
          expect(response.body).to match(%r{/organizations/[^/]+/assignments/#{assignment.id}})
        end

        it 'displays assignment_ability results with links to both assignment and ability' do
          get organization_bulk_sync_event_path(organization, bulk_sync_event)
          expect(response.body).to include(assignment.title)
          expect(response.body).to include(ability.name)
          # Check for both the assignment and ability paths in the HTML
          expect(response.body).to match(%r{/organizations/[^/]+/assignments/#{assignment.id}})
          expect(response.body).to match(%r{/organizations/[^/]+/abilities/#{ability.id}})
        end

        it 'displays position_assignment results with links to both position and assignment' do
          get organization_bulk_sync_event_path(organization, bulk_sync_event)
          expect(response.body).to include(position.display_name)
          expect(response.body).to include(assignment.title)
          # Check for both the position and assignment paths in the HTML
          expect(response.body).to match(%r{/organizations/[^/]+/positions/#{position.id}})
          expect(response.body).to match(%r{/organizations/[^/]+/assignments/#{assignment.id}})
        end

        it 'displays status information' do
          get organization_bulk_sync_event_path(organization, bulk_sync_event)
          expect(response.body).to include('Completed')
          expect(response.body).to include(bulk_sync_event.filename)
        end
      end

      context 'when user does not have can_manage_maap permission' do
        before do
          person_teammate
          sign_in_as_teammate_for_request(person, organization)
        end

        it 'denies access to show page' do
          get organization_bulk_sync_event_path(organization, bulk_sync_event)
          # Pundit redirects unauthorized users, so we expect a redirect
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(root_path)
        end
      end

      context 'when user has can_manage_employment permission but not maap' do
        before do
          employment_teammate
          sign_in_as_teammate_for_request(employment_teammate.person, organization)
        end

        it 'denies access to UploadAssignmentsAndAbilities events' do
          get organization_bulk_sync_event_path(organization, bulk_sync_event)
          # Pundit redirects unauthorized users, so we expect a redirect
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(root_path)
        end
      end

      context 'when user is admin' do
        before do
          admin_teammate
          sign_in_as_teammate_for_request(admin, organization)
        end

        it 'allows access to show page' do
          get organization_bulk_sync_event_path(organization, bulk_sync_event)
          expect(response).to have_http_status(:success)
        end
      end
    end

    context 'with failed event' do
      let(:bulk_sync_event) do
        create(:upload_assignments_and_abilities,
          organization: organization,
          creator: person,
          initiator: person,
          status: 'failed',
          results: {
            'error' => 'Processing failed: Database connection error',
            'failures' => [
              {
                'type' => 'assignment',
                'error' => 'Validation failed',
                'data' => { 'title' => 'Test Assignment' },
                'row' => 2
              }
            ]
          }
        )
      end

      context 'when user has can_manage_maap permission' do
        before do
          maap_teammate
          sign_in_as_teammate_for_request(maap_manager, organization)
        end

        it 'displays failed status' do
          get organization_bulk_sync_event_path(organization, bulk_sync_event)
          expect(response.body).to include('Processing Failed')
          expect(response.body).to include('Database connection error')
        end

        it 'displays failure details' do
          get organization_bulk_sync_event_path(organization, bulk_sync_event)
          expect(response.body).to include('Failed Operations')
          expect(response.body).to include('Validation failed')
        end
      end
    end

    context 'with preview event' do
      let(:bulk_sync_event) do
        create(:upload_assignments_and_abilities,
          organization: organization,
          creator: person,
          initiator: person,
          status: 'preview',
          preview_actions: {
            'assignments' => [
              {
                'title' => 'Test Assignment',
                'tagline' => 'Test tagline',
                'outcomes_count' => 2,
                'required_activities' => 'Activity 1',
                'row' => 2,
                'action' => 'create',
                'will_create' => true,
                'existing_id' => nil
              }
            ],
            'abilities' => [
              {
                'name' => 'Test Ability',
                'row' => 3,
                'action' => 'create',
                'will_create' => true,
                'existing_id' => nil
              }
            ],
            'assignment_abilities' => [],
            'position_assignments' => []
          }
        )
      end

      context 'when user has can_manage_maap permission' do
        before do
          maap_teammate
          sign_in_as_teammate_for_request(maap_manager, organization)
        end

        it 'displays preview actions' do
          get organization_bulk_sync_event_path(organization, bulk_sync_event)
          expect(response.body).to include('Preview Actions')
          expect(response.body).to include('Test Assignment')
          expect(response.body).to include('Test Ability')
        end

        it 'displays process button' do
          get organization_bulk_sync_event_path(organization, bulk_sync_event)
          expect(response.body).to include('Process Selected Items')
        end
      end
    end
  end
end

