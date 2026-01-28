require 'rails_helper'

RSpec.describe 'Organizations::Employees#audit', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:employee) { create(:person) }
  let(:manager) { create(:person) }
  let(:maap_manager) { create(:person) }
  let!(:employee_teammate) { create(:company_teammate, person: employee, organization: organization, first_employed_at: 1.year.ago) }
  let!(:manager_teammate) { create(:company_teammate, person: manager, organization: organization, first_employed_at: 1.year.ago) }
  let!(:maap_manager_teammate) { create(:company_teammate, person: maap_manager, organization: organization, can_manage_maap: true, can_manage_employment: true, first_employed_at: 1.year.ago) }
  let!(:employee_employment) { create(:employment_tenure, teammate: employee_teammate, company: organization, started_at: 1.year.ago) }
  let!(:manager_employment) { create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago) }
  let!(:maap_manager_employment) { create(:employment_tenure, teammate: maap_manager_teammate, company: organization, started_at: 1.year.ago) }
  
  let(:maap_snapshot1) do
    create(:maap_snapshot,
      employee_company_teammate: employee_teammate,
      creator_company_teammate: maap_manager_teammate,
      company: organization,
      change_type: 'assignment_management',
      reason: 'Assignment updates',
      effective_date: 1.day.ago,
      employee_acknowledged_at: nil
    )
  end

  let(:maap_snapshot2) do
    create(:maap_snapshot,
      employee_company_teammate: employee_teammate,
      creator_company_teammate: maap_manager_teammate,
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
      get audit_organization_employee_path(organization, employee_teammate)
      expect(response).to be_successful
    end
    
    it 'assigns the correct variables' do
      get audit_organization_employee_path(organization, employee_teammate)
      
      expect(assigns(:person)).to eq(employee)
      expect(assigns(:organization)).to be_a(Organization)
      expect(assigns(:organization).id).to eq(organization.id)
      expect(assigns(:maap_snapshots)).to include(maap_snapshot1, maap_snapshot2)
    end
    
    it 'only shows MAAP snapshots for the specific organization' do
      other_company = create(:organization, :company)
      other_employee_tm = create(:company_teammate, person: employee, organization: other_company)
      other_creator_tm = create(:company_teammate, person: maap_manager, organization: other_company)
      other_snapshot = create(:maap_snapshot, employee_company_teammate: other_employee_tm, creator_company_teammate: other_creator_tm, company: other_company)

      get audit_organization_employee_path(organization, employee_teammate)
      
      expect(assigns(:maap_snapshots)).to include(maap_snapshot1, maap_snapshot2)
      expect(assigns(:maap_snapshots)).not_to include(other_snapshot)
    end
    
    it 'renders the audit view template' do
      get audit_organization_employee_path(organization, employee_teammate)
      expect(response).to render_template(:audit)
    end
    
    it 'includes snapshot details in the response' do
      get audit_organization_employee_path(organization, employee_teammate)
      
      expect(response.body).to include(maap_snapshot1.reason)
      expect(response.body).to include(maap_snapshot2.reason)
    end
    
    it 'displays reason field in snapshot rows' do
      get audit_organization_employee_path(organization, employee_teammate)
      
      # Verify reason column header exists
      expect(response.body).to include('Reason')
      
      # Verify reasons are displayed in the table
      expect(response.body).to include(maap_snapshot1.reason)
      expect(response.body).to include(maap_snapshot2.reason)
    end
    
    it 'displays custom reasons correctly' do
      custom_snapshot = create(:maap_snapshot,
                               employee_company_teammate: employee_teammate,
                               creator_company_teammate: maap_manager_teammate,
                               company: organization,
                               change_type: 'bulk_check_in_finalization',
                               reason: 'Q4 2024 Performance Review',
                               effective_date: Date.current)
      
      get audit_organization_employee_path(organization, employee_teammate)
      
      expect(response.body).to include('Q4 2024 Performance Review')
      expect(response.body).to include(custom_snapshot.reason)
    end
  end
  
  describe 'when user does not have MAAP management permissions' do
    # User from another org cannot view this org's audit (policy: viewing_teammate.organization != record.organization)
    let(:other_org) { create(:organization, :company) }
    let(:other_org_person) { create(:person) }
    let!(:other_org_teammate) { create(:company_teammate, person: other_org_person, organization: other_org, first_employed_at: 1.year.ago) }

    before do
      sign_in_as_teammate_for_request(other_org_person, other_org)
    end

    it 'redirects when authorization fails' do
      get audit_organization_employee_path(organization, employee_teammate)
      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'when user is same-org teammate with no permissions and no direct reports' do
    # Peer: same org as target, no can_manage_employment/can_manage_maap, not in managerial hierarchy of employee
    let(:peer) { create(:person) }
    let!(:peer_teammate) do
      create(:company_teammate, person: peer, organization: organization, first_employed_at: 1.year.ago)
    end
    let!(:peer_employment) do
      create(:employment_tenure, teammate: peer_teammate, company: organization, started_at: 1.year.ago)
    end

    before do
      sign_in_as_teammate_for_request(peer, organization)
    end

    it 'redirects when trying to view another teammate\'s audit' do
      get audit_organization_employee_path(organization, employee_teammate)
      expect(response).to have_http_status(:redirect)
    end
  end
  
  describe 'when user is the employee themselves' do
    before do
      sign_in_as_teammate_for_request(employee, organization)
    end
    
    it 'allows access to own audit view' do
      get audit_organization_employee_path(organization, employee_teammate)
      expect(response).to be_successful
    end
    
    it 'assigns pending snapshots' do
      get audit_organization_employee_path(organization, employee_teammate)
      
      expect(assigns(:pending_snapshots)).to be_present
      expect(assigns(:pending_snapshots)).to include(maap_snapshot1)
      expect(assigns(:pending_snapshots)).not_to include(maap_snapshot2) # This one is acknowledged
    end
    
    it 'assigns acknowledged snapshots' do
      get audit_organization_employee_path(organization, employee_teammate)
      
      expect(assigns(:acknowledged_snapshots)).to be_present
      expect(assigns(:acknowledged_snapshots)).to include(maap_snapshot2)
      expect(assigns(:acknowledged_snapshots)).not_to include(maap_snapshot1) # This one is pending
    end
    
    it 'shows pending acknowledgements section' do
      get audit_organization_employee_path(organization, employee_teammate)
      
      expect(response.body).to include('Pending Acknowledgements')
      expect(response.body).to include('select_all_snapshots')
    end
    
    it 'renders snapshot_row partial for pending snapshots' do
      get audit_organization_employee_path(organization, employee_teammate)

      # Check that the snapshot data is present in the response
      expect(response.body).to include(maap_snapshot1.creator_company_teammate&.person&.display_name)
      expect(response.body).to include(maap_snapshot1.reason)
    end
    
    it 'renders snapshot_row partial for audit trail' do
      get audit_organization_employee_path(organization, employee_teammate)
      
      # Check that both snapshots appear in the audit trail
      expect(response.body).to include(maap_snapshot1.reason)
      expect(response.body).to include(maap_snapshot2.reason)
    end
  end
  
  describe 'when there are no snapshots' do
    let(:employee_without_snapshots) { create(:person) }
    let!(:employee_without_snapshots_teammate) { create(:company_teammate, person: employee_without_snapshots, organization: organization, first_employed_at: 1.year.ago) }
    let!(:employee_without_snapshots_employment) { create(:employment_tenure, teammate: employee_without_snapshots_teammate, company: organization, started_at: 1.year.ago) }
    
    before do
      sign_in_as_teammate_for_request(maap_manager, organization)
    end
    
    it 'renders successfully with empty state' do
      get audit_organization_employee_path(organization, employee_without_snapshots_teammate)
      
      expect(response).to be_successful
      expect(assigns(:maap_snapshots)).to be_empty
      expect(response.body).to include('No MAAP Changes Found')
    end
  end
  
  describe 'authorization edge cases' do
    context 'when employee does not exist in organization' do
      let(:other_organization) { create(:organization, :company) }
      let(:other_employee) { create(:person) }
      let!(:other_employee_teammate) { create(:company_teammate, person: other_employee, organization: other_organization, first_employed_at: 1.year.ago) }
      let!(:other_employee_employment) { create(:employment_tenure, teammate: other_employee_teammate, company: other_organization, started_at: 1.year.ago) }
      
      before do
        sign_in_as_teammate_for_request(maap_manager, organization)
      end
      
      it 'handles employee not found in organization gracefully' do
        # Use an id that is not any teammate or employee in this org (controller tries teammate then person)
        get audit_organization_employee_path(organization, 999999999)
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

