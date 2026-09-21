require 'rails_helper'

RSpec.describe 'Organizations::Assignments::ConsumerAssignments', type: :request do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization, title: 'Core Assignment') }
  let(:upstream) { create(:assignment, company: organization, title: 'Upstream Assignment') }
  let(:downstream) { create(:assignment, company: organization, title: 'Downstream Assignment') }
  let(:other) { create(:assignment, company: organization, title: 'Other Assignment') }

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

      it 'renders the reliance manage page' do
        upstream

        get organization_assignment_consumer_assignments_path(organization, assignment)
        expect(response.body).to include('Manage assignment reliance for')
        expect(response.body).to include(assignment.title)
        expect(response.body).to include('Upstream of this assignment')
        expect(response.body).to include('Downstream of this assignment')
        expect(response.body).to include('No Association')
        expect(response.body).to include('Save Assignment Reliance')
      end

      it 'shows all assignments in organization hierarchy' do
        assignment
        upstream
        downstream

        get organization_assignment_consumer_assignments_path(organization, assignment)

        expect(response.body).to include(upstream.title)
        expect(response.body).to include(downstream.title)
        expect(response.body).not_to match(/assignment_reliance_#{assignment.id}_direction/)
      end

      it 'marks existing upstream and downstream associations' do
        create(:assignment_supply_relationship, supplier_assignment: upstream, consumer_assignment: assignment)
        create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: downstream)

        get organization_assignment_consumer_assignments_path(organization, assignment)

        upstream_checked = response.body[%r{id=["']assignment_reliance_#{upstream.id}_direction_upstream["'][^>]*>}]
        downstream_checked = response.body[%r{id=["']assignment_reliance_#{downstream.id}_direction_downstream["'][^>]*>}]
        expect(upstream_checked).to include('checked')
        expect(downstream_checked).to include('checked')
      end

      it 'shows configure section when associations exist and collapses add section' do
        create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: downstream)
        other

        get organization_assignment_consumer_assignments_path(organization, assignment)

        expect(response.body).to include('Configure Assignment Reliance')
        expect(response.body).to include('Add Assignment Reliance')
        expect(response.body).to include('Click to expand if')
      end

      it 'expands add section when no associations exist' do
        upstream

        get organization_assignment_consumer_assignments_path(organization, assignment)

        expect(response.body).to include('No assignment reliance yet')
        expect(response.body).to include('addAssignmentReliance')
        expect(response.body).to include('class="collapse show"')
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

      it 'creates upstream and downstream relationships' do
        expect {
          patch organization_assignment_consumer_assignments_path(organization, assignment), params: {
            assignment_reliance: {
              upstream.id => { direction: 'upstream' },
              downstream.id => { direction: 'downstream' },
              other.id => { direction: 'none' }
            }
          }
        }.to change(AssignmentSupplyRelationship, :count).by(2)

        expect(assignment.reload.supplier_assignments).to include(upstream)
        expect(assignment.consumer_assignments).to include(downstream)
      end

      it 'removes relationships marked none' do
        create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: downstream)
        create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: other)

        expect {
          patch organization_assignment_consumer_assignments_path(organization, assignment), params: {
            assignment_reliance: {
              downstream.id => { direction: 'downstream' },
              other.id => { direction: 'none' }
            }
          }
        }.to change(AssignmentSupplyRelationship, :count).by(-1)

        assignment.reload
        expect(assignment.consumer_assignments).to include(downstream)
        expect(assignment.consumer_assignments).not_to include(other)
      end

      it 'switches a relationship from downstream to upstream' do
        create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: other)

        patch organization_assignment_consumer_assignments_path(organization, assignment), params: {
          assignment_reliance: {
            other.id => { direction: 'upstream' }
          }
        }

        assignment.reload
        expect(assignment.consumer_assignments).not_to include(other)
        expect(assignment.supplier_assignments).to include(other)
      end

      it 'redirects to assignment show page' do
        patch organization_assignment_consumer_assignments_path(organization, assignment), params: {
          assignment_reliance: {
            downstream.id => { direction: 'downstream' }
          }
        }
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include(organization_assignment_path(organization, assignment))
      end

      it 'shows success notice' do
        patch organization_assignment_consumer_assignments_path(organization, assignment), params: {
          assignment_reliance: {
            downstream.id => { direction: 'downstream' }
          }
        }
        follow_redirect!
        expect(response.body).to include('Assignment reliance was successfully updated')
      end

      it 'handles clearing all reliance' do
        create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: downstream)

        patch organization_assignment_consumer_assignments_path(organization, assignment), params: {
          assignment_reliance: {
            downstream.id => { direction: 'none' }
          }
        }

        expect(assignment.reload.consumer_assignments).to be_empty
      end
    end

    context 'when user has MAAP permission' do
      before do
        maap_teammate
        sign_in_as_teammate_for_request(maap_person, organization)
      end

      it 'creates relationships' do
        expect {
          patch organization_assignment_consumer_assignments_path(organization, assignment), params: {
            assignment_reliance: {
              downstream.id => { direction: 'downstream' }
            }
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
          assignment_reliance: {
            downstream.id => { direction: 'downstream' }
          }
        }

        expect(response).to redirect_to(root_path)
        expect(assignment.consumer_assignments).to be_empty
      end
    end
  end
end
