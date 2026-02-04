require 'rails_helper'

RSpec.describe 'Organizations::Assignments::ConsumerAssignments', type: :request do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization, title: 'Supplier Assignment') }
  let(:consumer1) { create(:assignment, company: organization, title: 'Consumer Assignment 1') }
  let(:consumer2) { create(:assignment, company: organization, title: 'Consumer Assignment 2') }
  let(:consumer3) { create(:assignment, company: organization, title: 'Consumer Assignment 3') }
  
  let(:admin) { create(:person, :admin) }
  let(:maap_person) { create(:person) }
  let(:regular_person) { create(:person) }
  
  let(:admin_teammate) { create(:teammate, person: admin, organization: organization) }
  let(:maap_teammate) { create(:teammate, person: maap_person, organization: organization, can_manage_maap: true) }
  let(:regular_teammate) { create(:teammate, person: regular_person, organization: organization) }

  before do
    PaperTrail.enabled = false
  end

  after do
    PaperTrail.enabled = true
  end

  describe 'GET /organizations/:organization_id/assignments/:assignment_id/consumer_assignments' do
    context 'when user is admin' do
      before do
        admin_teammate
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'returns success' do
        get organization_assignment_consumer_assignments_path(organization, assignment)
        expect(response).to have_http_status(:success)
      end

      it 'renders the show template' do
        get organization_assignment_consumer_assignments_path(organization, assignment)
        expect(response.body).to include('Manage Consumer Assignments')
        expect(response.body).to include(assignment.title)
        expect(response.body).to include('Select Consumer Assignments')
      end

      it 'shows all assignments in organization hierarchy' do
        # Ensure assignments are created before the request
        assignment
        consumer1
        consumer2
        
        get organization_assignment_consumer_assignments_path(organization, assignment)
        
        expect(response.body).to include(consumer1.title)
        expect(response.body).to include(consumer2.title)
        # Current assignment should not appear in the checkbox list (but may appear in header)
        expect(response.body).not_to match(/consumer_assignment_#{assignment.id}/)
      end

      it 'shows existing consumer assignments as checked' do
        # Create an existing relationship
        AssignmentSupplyRelationship.create!(
          supplier_assignment: assignment,
          consumer_assignment: consumer1
        )
        
        get organization_assignment_consumer_assignments_path(organization, assignment)
        
        # Check that the checkbox for consumer1 exists and is checked
        # check_box_tag generates HTML with checked attribute when the value is true
        checkbox_html = response.body[/<input[^>]*id=["']consumer_assignment_#{consumer1.id}["'][^>]*>/]
        expect(checkbox_html).to be_present
        expect(checkbox_html).to include('checked')
      end

      it 'shows unchecked assignments that are not consumers' do
        # Ensure consumer2 is created before the request
        consumer2
        
        # consumer2 is not a consumer
        get organization_assignment_consumer_assignments_path(organization, assignment)
        
        # The checkbox should exist but not be checked
        # The checkbox ID should be in the response
        expect(response.body).to include("consumer_assignment_#{consumer2.id}")
        # Find the position of the checkbox ID and extract the input tag
        id_index = response.body.index("consumer_assignment_#{consumer2.id}")
        expect(id_index).to be_present
        # Look backwards to find the start of the input tag
        tag_start = response.body.rindex('<input', id_index)
        # Look forwards to find the end of the input tag
        tag_end = response.body.index('>', id_index)
        if tag_start && tag_end
          input_tag = response.body[tag_start..tag_end]
          # The checked attribute should not appear in the input tag
          expect(input_tag).not_to match(/\schecked(\s|>|=)/)
        else
          # Fallback: just verify the ID exists (the checkbox is there)
          expect(id_index).to be_present
        end
      end

      it 'shows enabled save button' do
        get organization_assignment_consumer_assignments_path(organization, assignment)
        expect(response.body).to include('Save Consumer Assignments')
        expect(response.body).not_to include('disabled')
      end
    end

    context 'when user has MAAP permission' do
      before do
        maap_teammate
        sign_in_as_teammate_for_request(maap_person, organization)
      end

      it 'returns success' do
        get organization_assignment_consumer_assignments_path(organization, assignment)
        expect(response).to have_http_status(:success)
      end

      it 'shows enabled save button' do
        get organization_assignment_consumer_assignments_path(organization, assignment)
        expect(response.body).to include('Save Consumer Assignments')
        expect(response.body).not_to include('disabled')
      end
    end

    context 'when user does not have MAAP permission' do
      before do
        regular_teammate
        sign_in_as_teammate_for_request(regular_person, organization)
      end

      it 'denies access' do
        get organization_assignment_consumer_assignments_path(organization, assignment)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when no other assignments exist' do
      before do
        admin_teammate
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'shows message about no assignments found' do
        get organization_assignment_consumer_assignments_path(organization, assignment)
        expect(response.body).to include('No assignments found in this organization hierarchy')
      end
    end
  end

  describe 'PATCH /organizations/:organization_id/assignments/:assignment_id/consumer_assignments' do
    context 'when user is admin' do
      before do
        admin_teammate
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'creates new consumer assignment relationships' do
        expect {
          patch organization_assignment_consumer_assignments_path(organization, assignment), params: {
            consumer_assignment_ids: [consumer1.id, consumer2.id]
          }
        }.to change(AssignmentSupplyRelationship, :count).by(2)
        
        expect(assignment.consumer_assignments).to include(consumer1, consumer2)
      end

      it 'removes existing consumer assignment relationships' do
        # Create existing relationships
        AssignmentSupplyRelationship.create!(
          supplier_assignment: assignment,
          consumer_assignment: consumer1
        )
        AssignmentSupplyRelationship.create!(
          supplier_assignment: assignment,
          consumer_assignment: consumer2
        )
        
        expect {
          patch organization_assignment_consumer_assignments_path(organization, assignment), params: {
            consumer_assignment_ids: [consumer1.id]
          }
        }.to change(AssignmentSupplyRelationship, :count).by(-1)
        
        assignment.reload
        expect(assignment.consumer_assignments).to include(consumer1)
        expect(assignment.consumer_assignments).not_to include(consumer2)
      end

      it 'updates relationships correctly' do
        # Start with consumer1 as a consumer
        AssignmentSupplyRelationship.create!(
          supplier_assignment: assignment,
          consumer_assignment: consumer1
        )
        
        # Update to have consumer2 and consumer3 instead
        patch organization_assignment_consumer_assignments_path(organization, assignment), params: {
          consumer_assignment_ids: [consumer2.id, consumer3.id]
        }
        
        assignment.reload
        expect(assignment.consumer_assignments).not_to include(consumer1)
        expect(assignment.consumer_assignments).to include(consumer2, consumer3)
      end

      it 'redirects to assignment show page' do
        patch organization_assignment_consumer_assignments_path(organization, assignment), params: {
          consumer_assignment_ids: [consumer1.id]
        }
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include(organization_assignment_path(organization, assignment))
      end

      it 'shows success notice' do
        patch organization_assignment_consumer_assignments_path(organization, assignment), params: {
          consumer_assignment_ids: [consumer1.id]
        }
        follow_redirect!
        expect(response.body).to include('Consumer assignments were successfully updated')
      end

      it 'handles empty selection' do
        # Start with some relationships
        AssignmentSupplyRelationship.create!(
          supplier_assignment: assignment,
          consumer_assignment: consumer1
        )
        
        # Remove all relationships
        patch organization_assignment_consumer_assignments_path(organization, assignment), params: {
          consumer_assignment_ids: []
        }
        
        assignment.reload
        expect(assignment.consumer_assignments).to be_empty
      end
    end

    context 'when user has MAAP permission' do
      before do
        maap_teammate
        sign_in_as_teammate_for_request(maap_person, organization)
      end

      it 'creates new consumer assignment relationships' do
        expect {
          patch organization_assignment_consumer_assignments_path(organization, assignment), params: {
            consumer_assignment_ids: [consumer1.id]
          }
        }.to change(AssignmentSupplyRelationship, :count).by(1)
      end
    end

    context 'when user does not have MAAP permission' do
      before do
        regular_teammate
        sign_in_as_teammate_for_request(regular_person, organization)
      end

      it 'denies access' do
        patch organization_assignment_consumer_assignments_path(organization, assignment), params: {
          consumer_assignment_ids: [consumer1.id]
        }
        
        expect(response).to redirect_to(root_path)
        expect(assignment.consumer_assignments).to be_empty
      end
    end
  end
end
