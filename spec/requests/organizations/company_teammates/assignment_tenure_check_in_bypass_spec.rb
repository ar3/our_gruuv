require 'rails_helper'

RSpec.describe 'Assignment Tenure Check-in Bypass', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:department) { create(:organization, :department, parent: organization, name: 'Engineering') }
  let(:manager) { create(:person) }
  let(:employee) { create(:person) }
  
  let!(:manager_teammate) { create(:teammate, person: manager, organization: organization, can_manage_employment: true) }
  let!(:employee_teammate) { create(:teammate, person: employee, organization: organization, type: 'CompanyTeammate') }
  
  let!(:employment_tenure) do
    create(:employment_tenure,
      teammate: employee_teammate,
      company: organization,
      started_at: 1.month.ago,
      ended_at: nil)
  end
  
  let!(:assignment1) { create(:assignment, company: organization, department: department, title: 'Backend Development') }
  let!(:assignment2) { create(:assignment, company: organization, department: nil, title: 'Company-wide Initiative') }
  let!(:assignment3) { create(:assignment, company: organization, department: department, title: 'Frontend Development') }

  before do
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    manager_teammate.update!(first_employed_at: 1.year.ago)
    employee_teammate.update!(first_employed_at: 1.month.ago)
  end

  describe 'GET /organizations/:organization_id/company_teammates/:id/assignment_tenure_check_in_bypass' do
    context 'when user is a manager' do
      before do
        sign_in_as_teammate_for_request(manager, organization)
      end

      it 'allows access' do
        get assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to have_http_status(:success)
      end

      it 'renders the assignment_tenure_check_in_bypass template' do
        get assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to render_template(:assignment_tenure_check_in_bypass)
      end

      it 'loads all assignments for the organization' do
        get assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate)
        expect(assigns(:assignments)).to include(assignment1, assignment2, assignment3)
      end

      it 'loads all assignments in a single list' do
        get assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate)
        assignments = assigns(:assignments)
        expect(assignments).to include(assignment1, assignment2, assignment3)
      end

      it 'sorts assignments by full name including company and department hierarchy' do
        get assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate)
        assignments = assigns(:assignments)
        # Should be sorted alphabetically by full name (company > department > assignment)
        assignment_titles = assignments.map(&:title)
        expect(assignment_titles).to include('Backend Development', 'Frontend Development', 'Company-wide Initiative')
        # Verify they are sorted by building the full name manually
        full_names = assignments.map do |a|
          path = []
          path << a.company.name if a.company
          if a.department
            current = a.department
            dept_path = []
            while current
              dept_path.unshift(current.name)
              current = current.parent
            end
            path.concat(dept_path)
          end
          path << a.title
          path.join(' > ')
        end
        expect(full_names).to eq(full_names.sort)
      end

      it 'loads assignment data with tenure information' do
        active_tenure = create(:assignment_tenure,
          teammate: employee_teammate,
          assignment: assignment1,
          started_at: 1.month.ago,
          ended_at: nil,
          anticipated_energy_percentage: 50)
        
        get assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate)
        
        assignment_data = assigns(:assignment_data)[assignment1.id]
        expect(assignment_data[:latest_tenure]).to eq(active_tenure)
        expect(assignment_data[:latest_tenure].ended_at).to be_nil
      end

      it 'identifies assignments with ended tenure history' do
        ended_tenure = create(:assignment_tenure,
          teammate: employee_teammate,
          assignment: assignment1,
          started_at: 2.months.ago,
          ended_at: 1.month.ago,
          anticipated_energy_percentage: 30)
        
        get assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate)
        
        assignment_data = assigns(:assignment_data)[assignment1.id]
        expect(assignment_data[:latest_tenure]).to eq(ended_tenure)
        expect(assignment_data[:latest_tenure].ended_at).to be_present
      end

      it 'does not identify assignments with only check-in history (no tenure)' do
        create(:assignment_check_in,
          teammate: employee_teammate,
          assignment: assignment1,
          check_in_started_on: 1.week.ago)
        
        get assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate)
        
        assignment_data = assigns(:assignment_data)[assignment1.id]
        expect(assignment_data[:latest_tenure]).to be_nil
      end

      it 'loads latest tenure information' do
        active_tenure = create(:assignment_tenure,
          teammate: employee_teammate,
          assignment: assignment1,
          started_at: 3.months.ago,
          ended_at: nil,
          anticipated_energy_percentage: 40)
        
        get assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate)
        
        assignment_data = assigns(:assignment_data)[assignment1.id]
        expect(assignment_data[:latest_tenure]).to eq(active_tenure)
        expect(assignment_data[:latest_tenure].ended_at).to be_nil
      end
    end

    context 'when user has manage_employment permission' do
      let!(:manager_with_permission) { create(:person) }
      let!(:manager_teammate_with_permission) do
        create(:teammate, person: manager_with_permission, organization: organization, can_manage_employment: true)
      end

      before do
        create(:employment_tenure, teammate: manager_teammate_with_permission, company: organization, started_at: 1.year.ago, ended_at: nil)
        manager_teammate_with_permission.update!(first_employed_at: 1.year.ago)
        sign_in_as_teammate_for_request(manager_with_permission, organization)
      end

      it 'allows access' do
        get assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when user does not have manager or manage_employment permission' do
      let!(:regular_user) { create(:person) }
      let!(:regular_teammate) { create(:teammate, person: regular_user, organization: organization, can_manage_employment: false) }

      before do
        create(:employment_tenure, teammate: regular_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        regular_teammate.update!(first_employed_at: 1.year.ago)
        sign_in_as_teammate_for_request(regular_user, organization)
      end

      it 'denies access' do
        get assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate)
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is unauthenticated' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(nil)
      end

      it 'redirects to root path' do
        get assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'PATCH /organizations/:organization_id/company_teammates/:id/update_assignment_tenure_check_in_bypass' do
    before do
      sign_in_as_teammate_for_request(manager, organization)
    end

    context 'when updating existing active tenure' do
      let!(:active_tenure) do
        create(:assignment_tenure,
          teammate: employee_teammate,
          assignment: assignment1,
          started_at: 1.month.ago,
          ended_at: nil,
          anticipated_energy_percentage: 50)
      end

      it 'updates the energy percentage' do
        patch update_assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate),
              params: { assignment_tenures: { assignment1.id.to_s => '75' } }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(complete_picture_organization_company_teammate_path(organization, employee_teammate))
        active_tenure.reload
        expect(active_tenure.anticipated_energy_percentage).to eq(75)
      end

      it 'ends tenure when energy percentage is set to 0' do
        patch update_assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate),
              params: { assignment_tenures: { assignment1.id.to_s => '0' } }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(complete_picture_organization_company_teammate_path(organization, employee_teammate))
        active_tenure.reload
        expect(active_tenure.ended_at).to eq(Date.current)
        expect(active_tenure.anticipated_energy_percentage).to eq(0)
      end

      it 'does not change tenure when value is unchanged' do
        original_updated_at = active_tenure.updated_at
        
        patch update_assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate),
              params: { assignment_tenures: { assignment1.id.to_s => '50' } }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate))
        active_tenure.reload
        # Should still update due to transaction, but the values remain the same
        expect(active_tenure.anticipated_energy_percentage).to eq(50)
      end
    end

    context 'when creating new tenure' do
      it 'creates new tenure when energy percentage is greater than 0' do
        expect {
          patch update_assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate),
                params: { assignment_tenures: { assignment1.id.to_s => '60' } }
        }.to change(AssignmentTenure, :count).by(1)
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(complete_picture_organization_company_teammate_path(organization, employee_teammate))
        new_tenure = AssignmentTenure.last
        expect(new_tenure.teammate.id).to eq(employee_teammate.id)
        expect(new_tenure.assignment).to eq(assignment1)
        expect(new_tenure.anticipated_energy_percentage).to eq(60)
        expect(new_tenure.started_at).to eq(Date.current)
        expect(new_tenure.ended_at).to be_nil
      end

      it 'does not create tenure when energy percentage is 0' do
        expect {
          patch update_assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate),
                params: { assignment_tenures: { assignment1.id.to_s => '0' } }
        }.not_to change(AssignmentTenure, :count)
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate))
      end
    end

    context 'when creating MAAP snapshot' do
      let!(:active_tenure) do
        create(:assignment_tenure,
          teammate: employee_teammate,
          assignment: assignment1,
          started_at: 1.month.ago,
          ended_at: nil,
          anticipated_energy_percentage: 50)
      end

      it 'creates MAAP snapshot when changes are made' do
        expect {
          patch update_assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate),
                params: { assignment_tenures: { assignment1.id.to_s => '75' } }
        }.to change(MaapSnapshot, :count).by(1)
        
        snapshot = MaapSnapshot.last
        expect(snapshot.employee).to eq(employee)
        expect(snapshot.created_by).to eq(manager)
        expect(snapshot.change_type).to eq('assignment_management')
        expect(snapshot.reason).to eq('Check-in Bypass')
        expect(snapshot.manager_request_info).to include('ip_address', 'user_agent', 'timestamp')
        expect(snapshot.effective_date).to eq(Date.current)
        expect(snapshot.executed?).to be true
      end

      it 'does not create MAAP snapshot when no changes are made' do
        expect {
          patch update_assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate),
                params: { assignment_tenures: {} }
        }.not_to change(MaapSnapshot, :count)
      end

      it 'stores request info in MAAP snapshot' do
        patch update_assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate),
              params: { assignment_tenures: { assignment1.id.to_s => '75' } }
        
        snapshot = MaapSnapshot.last
        expect(snapshot.manager_request_info['ip_address']).to be_present
        expect(snapshot.manager_request_info['timestamp']).to be_present
        # user_agent may be nil in test environment
        expect(snapshot.manager_request_info).to have_key('user_agent')
        expect(snapshot.effective_date).to eq(Date.current)
        expect(snapshot.executed?).to be true
      end
    end

    context 'when updating multiple assignments' do
      let!(:tenure1) do
        create(:assignment_tenure,
          teammate: employee_teammate,
          assignment: assignment1,
          started_at: 1.month.ago,
          ended_at: nil,
          anticipated_energy_percentage: 50)
      end

      it 'updates multiple tenures in a single transaction' do
        patch update_assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate),
              params: {
                assignment_tenures: {
                  assignment1.id.to_s => '75',
                  assignment2.id.to_s => '25'
                }
              }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(complete_picture_organization_company_teammate_path(organization, employee_teammate))
        tenure1.reload
        expect(tenure1.anticipated_energy_percentage).to eq(75)
        
        new_tenure = AssignmentTenure.find_by(teammate: employee_teammate, assignment: assignment2)
        expect(new_tenure.anticipated_energy_percentage).to eq(25)
      end

      it 'creates single MAAP snapshot for multiple changes' do
        expect {
          patch update_assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate),
                params: {
                  assignment_tenures: {
                    assignment1.id.to_s => '75',
                    assignment2.id.to_s => '25'
                  }
                }
        }.to change(MaapSnapshot, :count).by(1)
        
        snapshot = MaapSnapshot.last
        expect(snapshot.effective_date).to eq(Date.current)
        expect(snapshot.executed?).to be true
      end
    end

    context 'when user does not have permission' do
      let!(:regular_user) { create(:person) }
      let!(:regular_teammate) { create(:teammate, person: regular_user, organization: organization, can_manage_employment: false) }

      before do
        create(:employment_tenure, teammate: regular_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        regular_teammate.update!(first_employed_at: 1.year.ago)
        sign_in_as_teammate_for_request(regular_user, organization)
      end

      it 'denies access' do
        # Verify no changes are made when access is denied
        expect {
          patch update_assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate),
                params: { assignment_tenures: { assignment1.id.to_s => '75' } }
        }.not_to change(AssignmentTenure, :count)
        
        expect(response).to have_http_status(:redirect)
        # Authorization error should redirect to root_path
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when assignment does not belong to organization' do
      let(:other_organization) { create(:organization, :company) }
      let!(:other_assignment) { create(:assignment, company: other_organization, title: 'Other Assignment') }

      it 'ignores assignments from other organizations' do
        expect {
          patch update_assignment_tenure_check_in_bypass_organization_company_teammate_path(organization, employee_teammate),
                params: { assignment_tenures: { other_assignment.id.to_s => '50' } }
        }.not_to change(AssignmentTenure, :count)
      end
    end
  end
end
