require 'rails_helper'

RSpec.describe Organizations::CompanyTeammatesController, type: :controller do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:employee) { create(:person) }
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization, can_manage_employment: true) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }

  before do
    # Set up employment for manager
    create(:employment_tenure, teammate: manager_teammate, company: organization)
    # Set up employment for employee
    create(:employment_tenure, teammate: employee_teammate, company: organization)
    
    # Set up session for authentication
    sign_in_as_teammate(manager, organization)
  end

  describe 'GET #internal' do
    context 'when user has teammate permissions' do
      before do
        # Set up proper authorization by allowing the policy method
        allow_any_instance_of(CompanyTeammatePolicy).to receive(:internal?).and_return(true)
      end

      it 'renders the internal page successfully' do
        get :internal, params: { organization_id: organization.id, id: employee_teammate.id }
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:internal)
      end

      it 'assigns the correct instance variables' do
        get :internal, params: { organization_id: organization.id, id: employee_teammate.id }
        
        expect(assigns(:teammate).person).to eq(employee)
        expect(assigns(:employment_tenures)).to be_present
        expect(assigns(:teammates)).to be_present
      end
    end
  end
end
