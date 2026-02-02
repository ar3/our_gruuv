require 'rails_helper'

RSpec.describe Organizations::Assignments::ConsumerAssignmentsController, type: :controller do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let(:maap_person) { create(:person) }
  let(:no_permission_person) { create(:person) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:consumer1) { create(:assignment, company: organization, title: 'Consumer 1') }
  let(:consumer2) { create(:assignment, company: organization, title: 'Consumer 2') }

  before do
    create(:teammate, person: person, organization: organization, can_manage_employment: true)
    create(:teammate, person: maap_person, organization: organization, can_manage_maap: true)
    create(:teammate, person: no_permission_person, organization: organization)
  end

  describe 'GET #show' do
    context 'with manage_maap permission' do
      before { sign_in_as_teammate(maap_person, organization) }

      it 'renders the show template' do
        get :show, params: { organization_id: organization.id, assignment_id: assignment.id }
        expect(response).to render_template(:show)
        expect(response).to have_http_status(:success)
      end

      it 'loads all assignments in organization hierarchy' do
        # Ensure assignments are created before the request
        assignment
        consumer1
        consumer2
        
        get :show, params: { organization_id: organization.id, assignment_id: assignment.id }
        
        # Debug: check what was loaded
        loaded_assignments = assigns(:assignments)
        expect(loaded_assignments).to be_present, "Expected assignments to be loaded, but got: #{loaded_assignments.inspect}"
        expect(loaded_assignments).to include(consumer1, consumer2)
        expect(loaded_assignments).not_to include(assignment) # Current assignment excluded
      end

      it 'loads existing consumer assignments' do
        AssignmentSupplyRelationship.create!(
          supplier_assignment: assignment,
          consumer_assignment: consumer1
        )
        get :show, params: { organization_id: organization.id, assignment_id: assignment.id }
        expect(assigns(:existing_consumer_assignment_ids)).to include(consumer1.id)
        expect(assigns(:existing_consumer_assignment_ids)).not_to include(consumer2.id)
      end

      it 'uses overlay layout' do
        get :show, params: { organization_id: organization.id, assignment_id: assignment.id }
        expect(response).to render_template(layout: 'overlay')
      end
    end

    context 'without manage_maap permission' do
      before { sign_in_as_teammate(no_permission_person, organization) }

      it 'denies access' do
        get :show, params: { organization_id: organization.id, assignment_id: assignment.id }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'PATCH #update' do
    context 'with manage_maap permission' do
      before { sign_in_as_teammate(maap_person, organization) }

      it 'creates new consumer assignment relationships' do
        expect {
          patch :update, params: {
            organization_id: organization.id,
            assignment_id: assignment.id,
            consumer_assignment_ids: [consumer1.id, consumer2.id]
          }
        }.to change(AssignmentSupplyRelationship, :count).by(2)
      end

      it 'removes existing consumer assignment relationships' do
        AssignmentSupplyRelationship.create!(
          supplier_assignment: assignment,
          consumer_assignment: consumer1
        )
        AssignmentSupplyRelationship.create!(
          supplier_assignment: assignment,
          consumer_assignment: consumer2
        )

        expect {
          patch :update, params: {
            organization_id: organization.id,
            assignment_id: assignment.id,
            consumer_assignment_ids: [consumer1.id]
          }
        }.to change(AssignmentSupplyRelationship, :count).by(-1)

        expect(assignment.consumer_assignments).to include(consumer1)
        expect(assignment.consumer_assignments).not_to include(consumer2)
      end

      it 'redirects to assignment show page with notice' do
        patch :update, params: {
          organization_id: organization.id,
          assignment_id: assignment.id,
          consumer_assignment_ids: [consumer1.id]
        }
        expect(response).to redirect_to(organization_assignment_path(organization, assignment))
        expect(flash[:notice]).to eq('Consumer assignments were successfully updated.')
      end
    end

    context 'without manage_maap permission' do
      before { sign_in_as_teammate(no_permission_person, organization) }

      it 'denies access' do
        patch :update, params: {
          organization_id: organization.id,
          assignment_id: assignment.id,
          consumer_assignment_ids: [consumer1.id]
        }
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
