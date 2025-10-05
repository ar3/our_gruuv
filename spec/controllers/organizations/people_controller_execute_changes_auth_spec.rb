require 'rails_helper'

RSpec.describe Organizations::PeopleController, type: :controller do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person, current_organization: organization) }
  let(:employee) { create(:person, current_organization: organization) }
  let(:maap_snapshot) { create(:maap_snapshot, employee: employee, created_by: manager, company: organization) }

  before do
    session[:current_person_id] = manager.id
    allow(controller).to receive(:current_person).and_return(manager)
    # Set up organization access for manager
    manager_teammate = create(:teammate, person: manager, organization: organization, can_manage_employment: true)
    # Set up organization access for employee
    employee_teammate = create(:teammate, person: employee, organization: organization)
    # Set up employment for manager
    create(:employment_tenure, teammate: manager_teammate, company: organization)
    # Set up employment for employee
    create(:employment_tenure, teammate: employee_teammate, company: organization)
  end

  describe 'GET #execute_changes' do
    context 'when user accesses execute_changes without proper authorization setup' do
      it 'redirects when authorization fails' do
        # Remove the authorization setup to trigger the error
        allow_any_instance_of(PersonPolicy).to receive(:manager?).and_return(false)
        
        get :execute_changes, params: { organization_id: organization.id, id: employee.id, maap_snapshot_id: maap_snapshot.id }
        
        # Should redirect due to authorization failure
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when user has proper authorization' do
      before do
        # Set up proper authorization by allowing the policy method
        allow_any_instance_of(PersonPolicy).to receive(:manager?).and_return(true)
      end

      it 'renders the execute_changes page successfully' do
        get :execute_changes, params: { organization_id: organization.id, id: employee.id, maap_snapshot_id: maap_snapshot.id }
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:execute_changes)
      end

      it 'assigns the correct instance variables' do
        get :execute_changes, params: { organization_id: organization.id, id: employee.id, maap_snapshot_id: maap_snapshot.id }
        
        expect(assigns(:person)).to eq(employee)
        expect(assigns(:maap_snapshot)).to eq(maap_snapshot)
        expect(assigns(:current_organization)).to be_a(Organization).and have_attributes(id: organization.id)
      end
    end
  end
end
