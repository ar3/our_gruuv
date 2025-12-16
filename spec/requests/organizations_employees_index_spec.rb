require 'rails_helper'

RSpec.describe 'Organizations::Employees#index', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:manager) { create(:person) }
  let(:direct_report) { create(:person) }
  
  before do
    # Create teammate with manage employment permission
    create(:teammate, person: person, organization: organization, can_manage_employment: true)
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
  end

  it 'renders without NoMethodError for unassigned employee uploads path' do
    expect {
      get organization_employees_path(organization)
    }.not_to raise_error
  end

  it 'renders the page successfully' do
    get organization_employees_path(organization)
    expect(response).to be_successful
  end

  it 'sets up all required instance variables' do
    get organization_employees_path(organization)
    expect(assigns(:organization)).to be_a(Organization)
    expect(assigns(:filtered_and_paginated_teammates)).to be_an(Array) # After pagination, teammates is an Array
    expect(assigns(:spotlight_stats)).to be_present
    expect(assigns(:current_filters)).to be_present
    expect(assigns(:current_sort)).to be_present
    expect(assigns(:current_view)).to be_present
    expect(assigns(:has_active_filters)).to be_present
  end

  describe 'manager filter functionality' do
    let!(:manager_teammate) { create(:teammate, type: 'CompanyTeammate', person: manager, organization: organization) }
    let(:direct_report_teammate) { create(:teammate, person: direct_report, organization: organization) }

    before do
      # Create employment tenure with manager relationship
      create(:employment_tenure, teammate: direct_report_teammate, company: organization, manager: manager, ended_at: nil)
      
      # Reload to ensure we have the CompanyTeammate instance
      manager_ct = CompanyTeammate.find(manager_teammate.id)
      
      # Mock authentication for manager
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager)
      allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(manager_ct)
    end

    it 'renders manager direct reports view successfully' do
      get organization_employees_path(organization, manager_id: manager.id, display: 'check_in_status')
      expect(response).to be_successful
    end

    it 'sets manager spotlight type when manager filter is active' do
      get organization_employees_path(organization, manager_id: manager.id, display: 'check_in_status')
      expect(assigns(:current_spotlight)).to eq('manager_overview')
    end

    it 'sets teammates spotlight type when no manager filter' do
      get organization_employees_path(organization)
      expect(assigns(:current_spotlight)).to eq('teammates_overview')
    end

    it 'includes manager_id in current_filters' do
      get organization_employees_path(organization, manager_id: manager.id)
      expect(assigns(:current_filters)[:manager_id]).to include(manager.id.to_s)
    end

    it 'includes multiple manager_ids in current_filters' do
      manager2 = create(:person)
      manager2_teammate = create(:teammate, person: manager2, organization: organization, first_employed_at: 1.month.ago)
      direct_report2 = create(:person)
      direct_report2_teammate = create(:teammate, person: direct_report2, organization: organization, first_employed_at: 1.month.ago)
      create(:employment_tenure, teammate: direct_report2_teammate, company: organization, manager: manager2, ended_at: nil)
      
      get organization_employees_path(organization, manager_id: [manager.id, manager2.id])
      expect(assigns(:current_filters)[:manager_id]).to include(manager.id.to_s, manager2.id.to_s)
    end

    it 'handles check_in_status display view' do
      get organization_employees_path(organization, display: 'check_in_status')
      expect(assigns(:current_view)).to eq('check_in_status')
    end

    it 'eager loads check-in data when using check_in_status display' do
      # Ensure we have at least one direct report (update existing tenure instead of creating new one)
      direct_report_teammate.update!(first_employed_at: 1.month.ago)
      existing_tenure = EmploymentTenure.find_by(teammate: direct_report_teammate, company: organization)
      if existing_tenure
        existing_tenure.update!(manager: manager, started_at: 1.month.ago, ended_at: nil)
      else
        create(:employment_tenure, teammate: direct_report_teammate, company: organization, manager: manager, started_at: 1.month.ago, ended_at: nil)
      end
      
      get organization_employees_path(organization, manager_id: manager.id, display: 'check_in_status')
      
      # Should have eager loaded associations
      expect(assigns(:filtered_and_paginated_teammates)).to be_present
      # The teammates should be properly loaded with associations
    end

    it 'calculates manager-specific spotlight stats' do
      get organization_employees_path(organization, manager_id: manager.id, display: 'check_in_status')
      
      spotlight_stats = assigns(:spotlight_stats)
      expect(spotlight_stats).to include(:total_direct_reports)
      expect(spotlight_stats).to include(:ready_for_finalization)
      expect(spotlight_stats).to include(:needs_manager_completion)
      expect(spotlight_stats).to include(:pending_acknowledgements)
      expect(spotlight_stats).to include(:team_health_score)
    end

    it 'handles empty direct reports gracefully' do
      # Remove the direct report
      EmploymentTenure.where(manager: manager).destroy_all
      
      get organization_employees_path(organization, manager_id: manager.id, display: 'check_in_status')
      
      # Should return empty results since manager has no direct reports
      expect(response).to be_successful
      teammates = assigns(:filtered_and_paginated_teammates)
      expect(teammates).to be_empty
    end

    it 'maintains pagination with manager filter' do
      # Create many direct reports (need at least 26 for page 2 with 25 items per page)
      30.times do |i|
        person = create(:person, first_name: "Employee#{i}", last_name: "Test")
        teammate = create(:teammate, person: person, organization: organization, first_employed_at: 1.month.ago)
        create(:employment_tenure, teammate: teammate, company: organization, manager: manager, started_at: 1.month.ago, ended_at: nil)
      end
      
      get organization_employees_path(organization, manager_id: manager.id, page: 2)
      
      expect(response).to be_successful
      expect(assigns(:filtered_and_paginated_teammates)).to be_present
    end
  end

  describe 'authorization' do
    let(:non_manager) { create(:person) }
    let!(:non_manager_teammate) { create(:teammate, type: 'CompanyTeammate', person: non_manager, organization: organization) }

    before do
      # Reload as CompanyTeammate to ensure has_direct_reports? method is available
      non_manager_ct = CompanyTeammate.find(non_manager_teammate.id)
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(non_manager)
      allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(non_manager_ct)
    end

    it 'allows non-manager to access manager filter view (shows empty if no direct reports)' do
      # Remove any direct reports for this manager
      EmploymentTenure.where(manager: manager).destroy_all
      
      get organization_employees_path(organization, manager_id: manager.id, display: 'check_in_status')
      
      expect(response).to be_successful
      teammates = assigns(:filtered_and_paginated_teammates)
      expect(teammates).to be_empty
      # Should show a message about no direct reports
      expect(response.body).to include("You don't have any direct reports")
    end

    it 'allows non-managers to access regular teammates view' do
      get organization_employees_path(organization)
      expect(response).to be_successful
    end
  end

  describe 'parameter handling' do
    it 'handles invalid manager_id values gracefully' do
      get organization_employees_path(organization, manager_id: 999999)
      expect(response).to be_successful
      expect(assigns(:current_filters)[:manager_id]).to include('999999')
    end

    it 'handles missing current_person with manager filter' do
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(nil)
      
      # Without a current_person, the manager filter should redirect (authentication likely kicks in)
      get organization_employees_path(organization, manager_id: manager.id)
      # Response will be redirected (either to employees path or root due to auth)
      expect(response).to be_redirect
    end

    it 'handles both view and display parameters' do
      get organization_employees_path(organization, view: 'cards', display: 'check_in_status')
      expect(assigns(:current_view)).to eq('check_in_status') # display should take precedence
    end

    it 'handles empty manager_id parameter' do
      get organization_employees_path(organization, manager_id: '')
      expect(response).to be_successful
      expect(assigns(:current_filters)[:manager_id]).to be_nil
    end

    it 'handles multiple manager_ids with empty values' do
      get organization_employees_path(organization, manager_id: ['', manager.id, ''])
      expect(response).to be_successful
      expect(assigns(:current_filters)[:manager_id]).to include(manager.id.to_s)
    end
  end

  describe 'integration with existing filters' do
    let(:manager_teammate) { create(:teammate, type: 'CompanyTeammate', person: manager, organization: organization) }
    let(:direct_report_teammate) { create(:teammate, person: direct_report, organization: organization) }

    before do
      create(:employment_tenure, teammate: direct_report_teammate, company: organization, manager: manager, ended_at: nil)
      
      # Reload as CompanyTeammate to ensure has_direct_reports? method is available
      manager_ct = CompanyTeammate.find(manager_teammate.id)
      
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager)
      allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(manager_ct)
    end

    it 'combines manager filter with status filter' do
      # Make direct report an assigned employee
      direct_report_teammate.update!(first_employed_at: 1.month.ago)
      
      get organization_employees_path(organization, manager_id: manager.id, status: 'assigned_employee')
      
      expect(response).to be_successful
      expect(assigns(:current_filters)[:manager_id]).to include(manager.id.to_s)
      # Status is now an array after expansion
      expect(assigns(:current_filters)[:status]).to include('assigned_employee')
    end

    it 'combines manager filter with permission filter' do
      direct_report_teammate.update!(can_manage_employment: true)
      
      get organization_employees_path(organization, manager_id: manager.id, permission: 'employment_mgmt')
      
      expect(response).to be_successful
      expect(assigns(:current_filters)[:manager_id]).to include(manager.id.to_s)
      expect(assigns(:current_filters)[:permission]).to eq('employment_mgmt')
    end

    it 'combines manager filter with organization filter' do
      child_org = create(:organization, parent: organization)
      child_teammate = create(:teammate, person: direct_report, organization: child_org)
      create(:employment_tenure, teammate: child_teammate, company: child_org, manager: manager, ended_at: nil)
      
      get organization_employees_path(organization, manager_id: manager.id, organization_id: child_org.id)
      
      expect(response).to be_successful
      expect(assigns(:current_filters)[:manager_id]).to include(manager.id.to_s)
      expect(assigns(:current_filters)[:organization_id]).to eq(child_org.id.to_s)
    end

    it 'combines manager filter with department filter' do
      department = create(:organization, type: 'Department', parent: organization)
      department_teammate = create(:teammate, person: direct_report, organization: department, first_employed_at: 1.month.ago)
      create(:employment_tenure, teammate: department_teammate, company: organization, manager: manager, ended_at: nil)
      
      get organization_employees_path(organization, manager_id: manager.id, department_id: department.id)
      
      expect(response).to be_successful
      expect(assigns(:current_filters)[:manager_id]).to include(manager.id.to_s)
      expect(assigns(:current_filters)[:department_id]).to include(department.id.to_s)
    end
  end

  describe 'status filtering' do
    let(:active_employee) { create(:person) }
    let(:unassigned_employee) { create(:person) }
    let(:terminated_employee) { create(:person) }
    let(:huddle_only_participant) { create(:person) }

    let!(:active_teammate) { create(:teammate, person: active_employee, organization: organization, first_employed_at: 1.month.ago) }
    let!(:unassigned_teammate) { create(:teammate, person: unassigned_employee, organization: organization, first_employed_at: 2.months.ago) }
    let!(:terminated_teammate) { create(:teammate, person: terminated_employee, organization: organization, first_employed_at: 6.months.ago, last_terminated_at: 1.month.ago) }
    let!(:huddle_only_teammate) { create(:teammate, person: huddle_only_participant, organization: organization, first_employed_at: nil, last_terminated_at: nil) }

    before do
      # Create employment tenure for active employee
      create(:employment_tenure, teammate: active_teammate, company: organization, started_at: 2.months.ago, ended_at: nil)
      # No employment tenure for unassigned (they have first_employed_at but no active tenure)
      # Create terminated employment tenure (started_at must be before ended_at)
      create(:employment_tenure, teammate: terminated_teammate, company: organization, started_at: 6.months.ago, ended_at: 1.month.ago)
      # Create huddle participation for huddle-only participant
      huddle_playbook = create(:huddle_playbook, organization: organization)
      huddle = create(:huddle, huddle_playbook: huddle_playbook)
      create(:huddle_participant, teammate: huddle_only_teammate, huddle: huddle)
    end

    describe 'default active filter' do
      it 'defaults to active filter when status is not specified' do
        get organization_employees_path(organization)
        
        expect(response).to be_successful
        # Status should be expanded to granular statuses for checkbox display
        expect(assigns(:current_filters)[:status]).to include('assigned_employee', 'unassigned_employee')
        
        # Should only include active employees
        teammate_ids = assigns(:filtered_and_paginated_teammates).map(&:id)
        expect(teammate_ids).to include(active_teammate.id)
        expect(teammate_ids).to include(unassigned_teammate.id)
        expect(teammate_ids).not_to include(terminated_teammate.id)
        expect(teammate_ids).not_to include(huddle_only_teammate.id)
      end

      it 'allows user to explicitly remove default filter by setting status to all_employed' do
        get organization_employees_path(organization, status: 'all_employed')
        
        expect(response).to be_successful
        # Status should be expanded to granular statuses for checkbox display
        expect(assigns(:current_filters)[:status]).to include('assigned_employee', 'unassigned_employee', 'terminated')
        
        # Should include all ever-employed teammates
        teammate_ids = assigns(:filtered_and_paginated_teammates).map(&:id)
        expect(teammate_ids).to include(active_teammate.id)
        expect(teammate_ids).to include(unassigned_teammate.id)
        expect(teammate_ids).to include(terminated_teammate.id)
        expect(teammate_ids).not_to include(huddle_only_teammate.id)
      end
    end

    describe 'huddle-only participants exclusion' do
      it 'excludes huddle-only participants with default active filter' do
        get organization_employees_path(organization)
        
        expect(response).to be_successful
        teammate_ids = assigns(:filtered_and_paginated_teammates).map(&:id)
        expect(teammate_ids).not_to include(huddle_only_teammate.id)
      end

      it 'excludes huddle-only participants with all_employed filter' do
        get organization_employees_path(organization, status: 'all_employed')
        
        expect(response).to be_successful
        teammate_ids = assigns(:filtered_and_paginated_teammates).map(&:id)
        expect(teammate_ids).not_to include(huddle_only_teammate.id)
      end
    end

    describe 'uniqueness' do
      it 'returns unique teammates even when joins might create duplicates' do
        # Create a teammate with multiple employment tenures
        person_with_multiple_tenures = create(:person)
        teammate_with_tenures = create(:teammate, person: person_with_multiple_tenures, organization: organization, first_employed_at: 3.months.ago)
        
      # Create multiple employment tenures (started_at must be before ended_at)
      create(:employment_tenure, teammate: teammate_with_tenures, company: organization, started_at: 3.months.ago, ended_at: 2.months.ago)
      create(:employment_tenure, teammate: teammate_with_tenures, company: organization, started_at: 2.months.ago, ended_at: nil)

        get organization_employees_path(organization)
        
        expect(response).to be_successful
        teammate_ids = assigns(:filtered_and_paginated_teammates).map(&:id)
        # Should only appear once despite multiple tenures
        expect(teammate_ids.count { |id| id == teammate_with_tenures.id }).to eq(1)
      end
    end
  end

  describe 'vertical_hierarchy view' do
    let(:company_org) { create(:organization, :company) }
    let(:employee_person) { create(:person) }
    let!(:employee_teammate) { create(:teammate, person: employee_person, organization: company_org, first_employed_at: 1.month.ago) }
    let!(:employment_tenure) { create(:employment_tenure, teammate: employee_teammate, company: company_org, started_at: 1.month.ago, ended_at: nil) }

    before do
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(employee_person)
      allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(company_org)
    end

    it 'does not raise NoMethodError when accessing vertical_hierarchy view with organization filter' do
      expect {
        get organization_employees_path(company_org, view: 'vertical_hierarchy', organization_id: company_org.id)
      }.not_to raise_error
      expect(response).to be_successful
      expect(assigns(:hierarchy_tree)).to be_an(Array)
    end

    it 'does not raise NoMethodError when accessing vertical_hierarchy view with permission filter' do
      expect {
        get organization_employees_path(company_org, view: 'vertical_hierarchy', permission: ['employment_mgmt'])
      }.not_to raise_error
      expect(response).to be_successful
      expect(assigns(:hierarchy_tree)).to be_an(Array)
    end

    it 'does not raise NoMethodError when accessing vertical_hierarchy view with manager filter' do
      manager = create(:person)
      manager_teammate = create(:teammate, person: manager, organization: company_org, first_employed_at: 1.month.ago)
      # Update existing employment tenure to have manager instead of creating a new one
      employment_tenure.update!(manager: manager)
      
      manager_ct = CompanyTeammate.find(manager_teammate.id)
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager)
      allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(manager_ct)

      expect {
        get organization_employees_path(company_org, view: 'vertical_hierarchy', manager_id: manager.id)
      }.not_to raise_error
      expect(response).to be_successful
      expect(assigns(:hierarchy_tree)).to be_an(Array)
    end

    it 'handles TeamTeammate objects in organization hierarchy without error' do
      # Create a company with a team descendant
      company = create(:organization, :company)
      team = create(:organization, type: 'Team', parent: company)
      
      # Create a person with both CompanyTeammate and TeamTeammate
      person = create(:person)
      company_teammate = create(:teammate, type: 'CompanyTeammate', person: person, organization: company, first_employed_at: 1.month.ago)
      team_teammate = create(:teammate, type: 'TeamTeammate', person: person, organization: team)
      
      # Create employment tenure for the company teammate
      create(:employment_tenure, teammate: company_teammate, company: company, started_at: 1.month.ago, ended_at: nil)
      
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
      allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(company)
      
      expect {
        get organization_employees_path(company, view: 'vertical_hierarchy')
      }.not_to raise_error
      expect(response).to be_successful
      # Verify no TeamTeammatePolicy error occurred
      expect(response.body).not_to include('TeamTeammatePolicy')
    end
  end

  describe 'department filter functionality' do
    let(:department) { create(:organization, type: 'Department', parent: organization) }
    let(:department2) { create(:organization, type: 'Department', parent: organization) }
    let(:employee_in_dept) { create(:person) }
    let(:employee_in_dept2) { create(:person) }
    let(:employee_no_dept) { create(:person) }
    
    let!(:dept_teammate) { create(:teammate, person: employee_in_dept, organization: department, first_employed_at: 1.month.ago) }
    let!(:dept2_teammate) { create(:teammate, person: employee_in_dept2, organization: department2, first_employed_at: 1.month.ago) }
    let!(:no_dept_teammate) { create(:teammate, person: employee_no_dept, organization: organization, first_employed_at: 1.month.ago) }

    before do
      create(:employment_tenure, teammate: dept_teammate, company: organization, started_at: 1.month.ago, ended_at: nil)
      create(:employment_tenure, teammate: dept2_teammate, company: organization, started_at: 1.month.ago, ended_at: nil)
      create(:employment_tenure, teammate: no_dept_teammate, company: organization, started_at: 1.month.ago, ended_at: nil)
    end

    it 'returns only teammates in selected department when department_id is set' do
      get organization_employees_path(organization, department_id: department.id)
      
      expect(response).to be_successful
      teammates = assigns(:filtered_and_paginated_teammates)
      
      # Should include teammate in department
      expect(teammates.map(&:id)).to include(dept_teammate.id)
      # Should NOT include teammates in other departments or no department
      expect(teammates.map(&:id)).not_to include(dept2_teammate.id)
      expect(teammates.map(&:id)).not_to include(no_dept_teammate.id)
    end

    it 'returns teammates from multiple departments when department_id[] is set' do
      get organization_employees_path(organization, department_id: [department.id, department2.id])
      
      expect(response).to be_successful
      teammates = assigns(:filtered_and_paginated_teammates)
      
      # Should include teammates from both departments
      expect(teammates.map(&:id)).to include(dept_teammate.id)
      expect(teammates.map(&:id)).to include(dept2_teammate.id)
      # Should NOT include teammate with no department
      expect(teammates.map(&:id)).not_to include(no_dept_teammate.id)
    end

    it 'includes department_id in current_filters' do
      get organization_employees_path(organization, department_id: department.id)
      expect(assigns(:current_filters)[:department_id]).to include(department.id.to_s)
    end

    it 'combines department filter with manager filter' do
      manager = create(:person)
      manager_teammate = create(:teammate, person: manager, organization: organization, first_employed_at: 1.month.ago)
      # Update existing tenure to have manager
      existing_tenure = EmploymentTenure.find_by(teammate: dept_teammate, company: organization)
      existing_tenure.update!(manager: manager) if existing_tenure
      
      get organization_employees_path(organization, department_id: department.id, manager_id: manager.id)
      
      expect(response).to be_successful
      teammates = assigns(:filtered_and_paginated_teammates)
      
      # Should only include teammate that matches both filters
      expect(teammates.map(&:id)).to include(dept_teammate.id)
      expect(teammates.map(&:id)).not_to include(dept2_teammate.id)
      expect(teammates.map(&:id)).not_to include(no_dept_teammate.id)
    end
  end

end
