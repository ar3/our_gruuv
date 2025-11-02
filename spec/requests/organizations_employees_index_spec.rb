require 'rails_helper'

RSpec.describe 'Organizations::Employees#index', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:manager) { create(:person) }
  let(:direct_report) { create(:person) }
  
  before do
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    # Allow the method to be called with any organization type
    allow(person).to receive(:can_manage_employment?).and_return(true)
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
    expect(assigns(:teammates)).to be_an(Array) # After pagination, teammates is an Array
    expect(assigns(:spotlight_stats)).to be_present
    expect(assigns(:current_filters)).to be_present
    expect(assigns(:current_sort)).to be_present
    expect(assigns(:current_view)).to be_present
    expect(assigns(:has_active_filters)).to be_present
  end

  describe 'manager filter functionality' do
    let(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
    let(:direct_report_teammate) { create(:teammate, person: direct_report, organization: organization) }

    before do
      # Create employment tenure with manager relationship
      create(:employment_tenure, teammate: direct_report_teammate, company: organization, manager: manager, ended_at: nil)
      
      # Mock authentication for manager
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager)
      # Allow has_direct_reports? to be called with any object (Organization or Company)
      allow(manager).to receive(:has_direct_reports?).and_return(true)
    end

    it 'renders manager direct reports view successfully' do
      get organization_employees_path(organization, manager_filter: 'direct_reports', display: 'check_in_status')
      expect(response).to be_successful
    end

    it 'sets manager spotlight type when manager filter is active' do
      get organization_employees_path(organization, manager_filter: 'direct_reports', display: 'check_in_status')
      expect(assigns(:spotlight_type)).to eq('manager_overview')
    end

    it 'sets teammates spotlight type when no manager filter' do
      get organization_employees_path(organization)
      expect(assigns(:spotlight_type)).to eq('teammates_overview')
    end

    it 'includes manager filter in current_filters' do
      get organization_employees_path(organization, manager_filter: 'direct_reports')
      expect(assigns(:current_filters)[:manager_filter]).to eq('direct_reports')
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
      
      get organization_employees_path(organization, manager_filter: 'direct_reports', display: 'check_in_status')
      
      # Should have eager loaded associations
      expect(assigns(:teammates)).to be_present
      # The teammates should be properly loaded with associations
    end

    it 'calculates manager-specific spotlight stats' do
      get organization_employees_path(organization, manager_filter: 'direct_reports', display: 'check_in_status')
      
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
      allow(manager).to receive(:has_direct_reports?).with(organization).and_return(false)
      
      get organization_employees_path(organization, manager_filter: 'direct_reports', display: 'check_in_status')
      
      expect(response).to be_successful
      expect(assigns(:teammates)).to be_empty
    end

    it 'maintains pagination with manager filter' do
      # Create many direct reports (need at least 26 for page 2 with 25 items per page)
      30.times do |i|
        person = create(:person, first_name: "Employee#{i}", last_name: "Test")
        teammate = create(:teammate, person: person, organization: organization, first_employed_at: 1.month.ago)
        create(:employment_tenure, teammate: teammate, company: organization, manager: manager, started_at: 1.month.ago, ended_at: nil)
      end
      
      get organization_employees_path(organization, manager_filter: 'direct_reports', page: 2)
      
      expect(response).to be_successful
      expect(assigns(:teammates)).to be_present
    end
  end

  describe 'authorization' do
    let(:non_manager) { create(:person) }

    before do
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(non_manager)
      allow(non_manager).to receive(:has_direct_reports?).and_return(false)
    end

    it 'redirects when non-manager tries to access direct reports view' do
      get organization_employees_path(organization, manager_filter: 'direct_reports', display: 'check_in_status')
      
      expect(response).to redirect_to(organization_employees_path(organization))
      follow_redirect!
      expect(response.body).to include('You do not have any direct reports')
    end

    it 'allows non-managers to access regular teammates view' do
      get organization_employees_path(organization)
      expect(response).to be_successful
    end
  end

  describe 'parameter handling' do
    it 'handles invalid manager_filter values gracefully' do
      get organization_employees_path(organization, manager_filter: 'invalid_filter')
      expect(response).to be_successful
      expect(assigns(:current_filters)[:manager_filter]).to eq('invalid_filter')
    end

    it 'handles missing current_person with manager filter' do
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(nil)
      
      # Without a current_person, the manager filter should redirect (authentication likely kicks in)
      get organization_employees_path(organization, manager_filter: 'direct_reports')
      # Response will be redirected (either to employees path or root due to auth)
      expect(response).to be_redirect
    end

    it 'handles both view and display parameters' do
      get organization_employees_path(organization, view: 'cards', display: 'check_in_status')
      expect(assigns(:current_view)).to eq('check_in_status') # display should take precedence
    end

    it 'handles empty manager_filter parameter' do
      get organization_employees_path(organization, manager_filter: '')
      expect(response).to be_successful
      expect(assigns(:current_filters)[:manager_filter]).to eq('')
    end
  end

  describe 'integration with existing filters' do
    let(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
    let(:direct_report_teammate) { create(:teammate, person: direct_report, organization: organization) }

    before do
      create(:employment_tenure, teammate: direct_report_teammate, company: organization, manager: manager, ended_at: nil)
      allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager)
      allow(manager).to receive(:has_direct_reports?).and_return(true)
    end

    it 'combines manager filter with status filter' do
      # Make direct report an assigned employee
      direct_report_teammate.update!(first_employed_at: 1.month.ago)
      
      get organization_employees_path(organization, manager_filter: 'direct_reports', status: 'assigned_employee')
      
      expect(response).to be_successful
      expect(assigns(:current_filters)[:manager_filter]).to eq('direct_reports')
      # Status is now an array after expansion
      expect(assigns(:current_filters)[:status]).to include('assigned_employee')
    end

    it 'combines manager filter with permission filter' do
      direct_report_teammate.update!(can_manage_employment: true)
      
      get organization_employees_path(organization, manager_filter: 'direct_reports', permission: 'employment_mgmt')
      
      expect(response).to be_successful
      expect(assigns(:current_filters)[:manager_filter]).to eq('direct_reports')
      expect(assigns(:current_filters)[:permission]).to eq('employment_mgmt')
    end

    it 'combines manager filter with organization filter' do
      child_org = create(:organization, parent: organization)
      child_teammate = create(:teammate, person: direct_report, organization: child_org)
      create(:employment_tenure, teammate: child_teammate, company: child_org, manager: manager, ended_at: nil)
      
      get organization_employees_path(organization, manager_filter: 'direct_reports', organization_id: child_org.id)
      
      expect(response).to be_successful
      expect(assigns(:current_filters)[:manager_filter]).to eq('direct_reports')
      expect(assigns(:current_filters)[:organization_id]).to eq(child_org.id.to_s)
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
        teammate_ids = assigns(:teammates).map(&:id)
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
        teammate_ids = assigns(:teammates).map(&:id)
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
        teammate_ids = assigns(:teammates).map(&:id)
        expect(teammate_ids).not_to include(huddle_only_teammate.id)
      end

      it 'excludes huddle-only participants with all_employed filter' do
        get organization_employees_path(organization, status: 'all_employed')
        
        expect(response).to be_successful
        teammate_ids = assigns(:teammates).map(&:id)
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
        teammate_ids = assigns(:teammates).map(&:id)
        # Should only appear once despite multiple tenures
        expect(teammate_ids.count { |id| id == teammate_with_tenures.id }).to eq(1)
      end
    end
  end

end
