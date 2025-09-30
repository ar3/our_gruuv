require 'rails_helper'

RSpec.describe Organizations::PeopleController, type: :controller do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person, current_organization: organization) }
  let(:employee) { create(:person, current_organization: organization) }

  let(:assignment) { create(:assignment, company: organization) }
  let(:assignment_tenure) { create(:assignment_tenure, person: employee, assignment: assignment, anticipated_energy_percentage: 50) }

  before do
    session[:current_person_id] = manager.id
    allow(controller).to receive(:current_person).and_return(manager)
    # Set up employment for manager
    create(:employment_tenure, person: manager, company: organization)
    # Set up employment for employee
    create(:employment_tenure, person: employee, company: organization)
    # Set up organization access for manager
    create(:person_organization_access, person: manager, organization: organization, can_manage_employment: true)
    # Set up organization access for employee
    create(:person_organization_access, person: employee, organization: organization)
    
    # Create assignment tenure to ensure @assignment_data is populated
    assignment_tenure
  end

  let(:maap_snapshot) do
    # Create a MAAP snapshot with assignment changes to ensure the partial gets rendered
    maap_data = {
      'assignments' => [
        {
          'id' => assignment.id,
          'tenure' => {
            'anticipated_energy_percentage' => 75,
            'started_at' => '2024-01-01'
          }
        }
      ]
    }
    create(:maap_snapshot, employee: employee, created_by: manager, company: organization, maap_data: maap_data)
  end

  describe 'GET #execute_changes' do
    context 'when user has proper authorization' do
      before do
        # Set up proper authorization by allowing the policy method
        allow_any_instance_of(PersonPolicy).to receive(:manager?).and_return(true)
        # Make sure the maap_snapshot was created by the current person to avoid redirect
        allow(maap_snapshot).to receive(:created_by).and_return(manager)
        # Don't mock assignment_has_changes? - let it use the real implementation
      end

      it 'successfully renders execute_changes template with person helper method available' do
        get :execute_changes, params: { organization_id: organization.id, id: employee.id, maap_snapshot_id: maap_snapshot.id }
        
        # Should render successfully now that person helper method is available
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:execute_changes)
      end
    end
  end
end
