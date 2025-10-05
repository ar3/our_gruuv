require 'rails_helper'

RSpec.describe Organizations::PeopleController, type: :controller do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person, current_organization: organization) }
  let(:employee) { create(:person, current_organization: organization) }

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

  describe 'GET #teammate' do
    context 'when user has teammate permissions' do
      before do
        # Set up proper authorization by allowing the policy method
        allow_any_instance_of(PersonPolicy).to receive(:teammate?).and_return(true)
      end

      it 'renders the teammate page successfully' do
        get :teammate, params: { organization_id: organization.id, id: employee.id }
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:teammate)
      end

      it 'assigns the correct instance variables' do
        get :teammate, params: { organization_id: organization.id, id: employee.id }
        
        expect(assigns(:person)).to eq(employee)
        expect(assigns(:current_organization)).to be_a(Organization).and have_attributes(id: organization.id)
        expect(assigns(:employment_tenures)).to be_present
        expect(assigns(:teammates)).to be_present
      end
    end
  end
end
