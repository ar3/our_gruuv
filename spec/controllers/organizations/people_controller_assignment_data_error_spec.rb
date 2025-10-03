require 'rails_helper'

RSpec.describe Organizations::PeopleController, type: :controller do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person, current_organization: organization) }
  let(:employee) { create(:person, current_organization: organization) }

  before do
    session[:current_person_id] = manager.id
    allow(controller).to receive(:current_person).and_return(manager)
    # Set up employment for manager
    create(:employment_tenure, person: manager, company: organization)
    # Set up employment for employee
    create(:employment_tenure, person: employee, company: organization)
    # Set up organization access for manager
    create(:teammate, person: manager, organization: organization, can_manage_employment: true)
    # Set up organization access for employee
    create(:teammate, person: employee, organization: organization)
  end

  let(:maap_snapshot) { create(:maap_snapshot, employee: employee, created_by: manager, company: organization) }

  describe 'GET #execute_changes' do
    context 'when user has proper authorization' do
      before do
        # Set up proper authorization by allowing the policy method
        allow_any_instance_of(PersonPolicy).to receive(:manager?).and_return(true)
        # Make sure the maap_snapshot was created by the current person to avoid redirect
        allow(maap_snapshot).to receive(:created_by).and_return(manager)
      end

      it 'successfully renders execute_changes template without NoMethodError' do
        get :execute_changes, params: { organization_id: organization.id, id: employee.id, maap_snapshot_id: maap_snapshot.id }
        
        # Should render successfully now that @assignment_data is set
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:execute_changes)
        expect(assigns(:assignment_data)).to be_an(Array)
      end
    end
  end
end
