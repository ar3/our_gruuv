require 'rails_helper'

RSpec.describe 'Organizations::Employees#audit', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:employee) { create(:person) }
  let(:manager) { create(:person) }
  let(:maap_manager) { create(:person) }
  let!(:employee_teammate) { create(:teammate, person: employee, organization: organization, first_employed_at: 1.year.ago) }
  let!(:manager_teammate) { create(:teammate, person: manager, organization: organization, first_employed_at: 1.year.ago) }
  let!(:maap_manager_teammate) { create(:teammate, person: maap_manager, organization: organization, can_manage_maap: true, can_manage_employment: true, first_employed_at: 1.year.ago) }
  let!(:employee_employment) { create(:employment_tenure, teammate: employee_teammate, company: organization, started_at: 1.year.ago) }
  let!(:manager_employment) { create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago) }
  let!(:maap_manager_employment) { create(:employment_tenure, teammate: maap_manager_teammate, company: organization, started_at: 1.year.ago) }
  
  let(:maap_snapshot1) do
    create(:maap_snapshot,
      employee: employee,
      created_by: maap_manager,
      company: organization,
      change_type: 'assignment_management',
      reason: 'Assignment updates',
      effective_date: 1.day.ago,
      employee_acknowledged_at: nil
    )
  end
  
  let(:maap_snapshot2) do
    create(:maap_snapshot,
      employee: employee,
      created_by: maap_manager,
      company: organization,
      change_type: 'position_tenure',
      reason: 'Position change',
      effective_date: 2.days.ago,
      employee_acknowledged_at: 1.day.ago
    )
  end
  
  before do
    maap_snapshot1
    maap_snapshot2
  end
  
  describe 'when user has MAAP management permissions' do
    before do
      sign_in_as_teammate_for_request(maap_manager, organization)
    end
    
    it 'renders the audit page successfully' do
      get audit_organization_employee_path(organization, employee)
      expect(response).to be_successful
    end
    
    it 'assigns the correct variables' do
      get audit_organization_employee_path(organization, employee)
      
      expect(assigns(:person)).to eq(employee)
      expect(assigns(:organization)).to be_a(Organization)
      expect(assigns(:organization).id).to eq(organization.id)
      expect(assigns(:maap_snapshots)).to include(maap_snapshot1, maap_snapshot2)
    end
    
    it 'only shows MAAP snapshots for the specific organization' do
      other_company = create(:organization, :company)
      other_snapshot = create(:maap_snapshot, employee: employee, created_by: maap_manager, company: other_company)
      
      get audit_organization_employee_path(organization, employee)
      
      expect(assigns(:maap_snapshots)).to include(maap_snapshot1, maap_snapshot2)
      expect(assigns(:maap_snapshots)).not_to include(other_snapshot)
    end
    
    it 'renders the audit view template' do
      get audit_organization_employee_path(organization, employee)
      expect(response).to render_template(:audit)
    end
    
    it 'includes snapshot details in the response' do
      get audit_organization_employee_path(organization, employee)
      
      expect(response.body).to include(maap_snapshot1.change_type.humanize)
      expect(response.body).to include(maap_snapshot2.change_type.humanize)
      expect(response.body).to include(maap_snapshot1.reason)
      expect(response.body).to include(maap_snapshot2.reason)
    end
    
    it 'displays reason field in snapshot rows' do
      get audit_organization_employee_path(organization, employee)
      
      # Verify reason column header exists
      expect(response.body).to include('Reason')
      
      # Verify reasons are displayed in the table
      expect(response.body).to include(maap_snapshot1.reason)
      expect(response.body).to include(maap_snapshot2.reason)
    end
    
    it 'displays custom reasons correctly' do
      custom_snapshot = create(:maap_snapshot,
                               employee: employee,
                               created_by: maap_manager,
                               company: organization,
                               change_type: 'bulk_check_in_finalization',
                               reason: 'Q4 2024 Performance Review',
                               effective_date: Date.current)
      
      get audit_organization_employee_path(organization, employee)
      
      expect(response.body).to include('Q4 2024 Performance Review')
      expect(response.body).to include(custom_snapshot.reason)
    end
  end
  
  describe 'when user does not have MAAP management permissions' do
    before do
      sign_in_as_teammate_for_request(manager, organization)
    end
    
    it 'redirects when authorization fails' do
      get audit_organization_employee_path(organization, employee)
      expect(response).to redirect_to(root_path)
    end
  end
  
  describe 'when user is the employee themselves' do
    before do
      sign_in_as_teammate_for_request(employee, organization)
    end
    
    it 'allows access to own audit view' do
      get audit_organization_employee_path(organization, employee)
      expect(response).to be_successful
    end
    
    it 'assigns pending snapshots' do
      get audit_organization_employee_path(organization, employee)
      
      expect(assigns(:pending_snapshots)).to be_present
      expect(assigns(:pending_snapshots)).to include(maap_snapshot1)
      expect(assigns(:pending_snapshots)).not_to include(maap_snapshot2) # This one is acknowledged
    end
    
    it 'assigns acknowledged snapshots' do
      get audit_organization_employee_path(organization, employee)
      
      expect(assigns(:acknowledged_snapshots)).to be_present
      expect(assigns(:acknowledged_snapshots)).to include(maap_snapshot2)
      expect(assigns(:acknowledged_snapshots)).not_to include(maap_snapshot1) # This one is pending
    end
    
    it 'shows pending acknowledgements section' do
      get audit_organization_employee_path(organization, employee)
      
      expect(response.body).to include('Pending Acknowledgements')
      expect(response.body).to include('select_all_snapshots')
    end
    
    it 'renders snapshot_row partial for pending snapshots' do
      get audit_organization_employee_path(organization, employee)
      
      # Check that the snapshot data is present in the response
      expect(response.body).to include(maap_snapshot1.change_type.humanize)
      expect(response.body).to include(maap_snapshot1.created_by.display_name)
    end
    
    it 'renders snapshot_row partial for audit trail' do
      get audit_organization_employee_path(organization, employee)
      
      # Check that both snapshots appear in the audit trail
      expect(response.body).to include(maap_snapshot1.change_type.humanize)
      expect(response.body).to include(maap_snapshot2.change_type.humanize)
    end
  end
  
  describe 'when there are no snapshots' do
    let(:employee_without_snapshots) { create(:person) }
    let!(:employee_without_snapshots_teammate) { create(:teammate, person: employee_without_snapshots, organization: organization, first_employed_at: 1.year.ago) }
    let!(:employee_without_snapshots_employment) { create(:employment_tenure, teammate: employee_without_snapshots_teammate, company: organization, started_at: 1.year.ago) }
    
    before do
      sign_in_as_teammate_for_request(maap_manager, organization)
    end
    
    it 'renders successfully with empty state' do
      get audit_organization_employee_path(organization, employee_without_snapshots)
      
      expect(response).to be_successful
      expect(assigns(:maap_snapshots)).to be_empty
      expect(response.body).to include('No MAAP Changes Found')
    end
  end
  
  describe 'authorization edge cases' do
    context 'when employee does not exist in organization' do
      let(:other_organization) { create(:organization, :company) }
      let(:other_employee) { create(:person) }
      let!(:other_employee_teammate) { create(:teammate, person: other_employee, organization: other_organization, first_employed_at: 1.year.ago) }
      let!(:other_employee_employment) { create(:employment_tenure, teammate: other_employee_teammate, company: other_organization, started_at: 1.year.ago) }
      
      before do
        sign_in_as_teammate_for_request(maap_manager, organization)
      end
      
      it 'handles employee not found in organization gracefully' do
        # The employee exists but is not an employee of the organization
        # The controller uses @organization.employees.find which should raise RecordNotFound
        # In request specs, exceptions are typically handled and return error responses
        get audit_organization_employee_path(organization, other_employee.id)
        expect(response.status).to be >= 400
      end
    end
    
    context 'when organization does not exist' do
      before do
        sign_in_as_teammate_for_request(maap_manager, organization)
      end
      
      it 'handles non-existent organization gracefully' do
        # Use a non-existent organization ID
        # The controller should handle this in before_action filters
        get "/organizations/99999/employees/#{employee.id}/audit"
        expect(response.status).to be >= 400
      end
    end
  end
end

