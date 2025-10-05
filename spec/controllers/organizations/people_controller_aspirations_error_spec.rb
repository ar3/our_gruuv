require 'rails_helper'

RSpec.describe Organizations::PeopleController, type: :controller do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person, current_organization: organization) }
  let(:employee) { create(:person, current_organization: organization) }

  before do
    session[:current_person_id] = manager.id
    allow(controller).to receive(:current_person).and_return(manager)
    # Set up employment for manager
    manager_teammate = create(:teammate, person: manager, organization: organization, can_manage_employment: true)
    create(:employment_tenure, teammate: manager_teammate, company: organization)
    # Set up employment for employee
    employee_teammate = create(:teammate, person: employee, organization: organization)
    create(:employment_tenure, teammate: employee_teammate, company: organization)
  end

  describe 'GET #execute_changes' do
    context 'when user has proper authorization' do
      let(:maap_snapshot) { create(:maap_snapshot, employee: employee, created_by: manager, company: organization) }
      
      before do
        # Set up proper authorization by allowing the policy method
        allow_any_instance_of(PersonPolicy).to receive(:manager?).and_return(true)
      end

      it 'successfully loads current MAAP data without NoMethodError' do
        get :execute_changes, params: { organization_id: organization.id, id: employee.id, maap_snapshot_id: maap_snapshot.id }
        
        # Should render successfully now that the NoMethodError is fixed
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:execute_changes)
      end
    end
  end
end
