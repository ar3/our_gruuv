require 'rails_helper'

RSpec.describe Organizations::Assignments::ConsumerAssignmentsController, type: :controller do
  let(:organization) { create(:organization) }
  let(:maap_person) { create(:person) }
  let(:no_permission_person) { create(:person) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:upstream) { create(:assignment, company: organization, title: 'Upstream') }
  let(:downstream) { create(:assignment, company: organization, title: 'Downstream') }

  before do
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

      it 'loads associated and available assignments' do
        create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: downstream)
        upstream

        get :show, params: { organization_id: organization.id, assignment_id: assignment.id }

        expect(assigns(:associated_assignments)).to include(downstream)
        expect(assigns(:associated_assignments)).not_to include(upstream)
        expect(assigns(:available_assignments)).to include(upstream)
        expect(assigns(:available_assignments)).not_to include(downstream)
        expect(assigns(:available_assignments)).not_to include(assignment)
      end

      it 'loads existing directions for upstream and downstream' do
        create(:assignment_supply_relationship, supplier_assignment: upstream, consumer_assignment: assignment)
        create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: downstream)

        get :show, params: { organization_id: organization.id, assignment_id: assignment.id }

        expect(assigns(:existing_directions_by_assignment_id)[upstream.id]).to eq('upstream')
        expect(assigns(:existing_directions_by_assignment_id)[downstream.id]).to eq('downstream')
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

      it 'creates upstream and downstream relationships' do
        expect {
          patch :update, params: {
            organization_id: organization.id,
            assignment_id: assignment.id,
            assignment_reliance: {
              upstream.id.to_s => { direction: 'upstream' },
              downstream.id.to_s => { direction: 'downstream' }
            }
          }
        }.to change(AssignmentSupplyRelationship, :count).by(2)
      end

      it 'removes relationships marked none' do
        create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: downstream)
        create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: upstream)

        expect {
          patch :update, params: {
            organization_id: organization.id,
            assignment_id: assignment.id,
            assignment_reliance: {
              downstream.id.to_s => { direction: 'downstream' },
              upstream.id.to_s => { direction: 'none' }
            }
          }
        }.to change(AssignmentSupplyRelationship, :count).by(-1)

        expect(assignment.reload.consumer_assignments).to include(downstream)
        expect(assignment.consumer_assignments).not_to include(upstream)
      end

      it 'redirects to assignment show page with notice' do
        patch :update, params: {
          organization_id: organization.id,
          assignment_id: assignment.id,
          assignment_reliance: {
            downstream.id.to_s => { direction: 'downstream' }
          }
        }
        expect(response).to redirect_to(organization_assignment_path(organization, assignment))
        expect(flash[:notice]).to eq('Assignment reliance was successfully updated.')
      end
    end

    context 'without manage_maap permission' do
      before { sign_in_as_teammate(no_permission_person, organization) }

      it 'denies access' do
        patch :update, params: {
          organization_id: organization.id,
          assignment_id: assignment.id,
          assignment_reliance: {
            downstream.id.to_s => { direction: 'downstream' }
          }
        }
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
