require 'rails_helper'

RSpec.describe 'Organizations::Employees#index with manager_lite spotlight', type: :request do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:direct_report1) { create(:person) }
  let(:direct_report2) { create(:person) }
  let!(:manager_teammate) { CompanyTeammate.create!(person: manager, organization: organization, first_employed_at: 1.month.ago) }
  let!(:direct_report1_teammate) { CompanyTeammate.create!(person: direct_report1, organization: organization, first_employed_at: 1.month.ago) }
  let!(:direct_report2_teammate) { CompanyTeammate.create!(person: direct_report2, organization: organization, first_employed_at: 1.month.ago) }

  before do
    # Create employment tenures with manager relationship
    create(:employment_tenure, teammate: direct_report1_teammate, company: organization, manager_teammate: manager_teammate, started_at: 1.month.ago, ended_at: nil)
    create(:employment_tenure, teammate: direct_report2_teammate, company: organization, manager_teammate: manager_teammate, started_at: 1.month.ago, ended_at: nil)
    
    # Mock authentication for manager
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager)
    allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(manager_teammate)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
  end

  describe 'GET #index with manager_lite spotlight and managers_view' do
    it 'renders successfully with manager_lite spotlight and managers_view' do
      get organization_employees_path(organization, spotlight: 'manager_lite', view: 'managers_view', manager_teammate_id: manager_teammate.id)
      
      expect(response).to be_successful
    end

    it 'sets the correct spotlight type' do
      get organization_employees_path(organization, spotlight: 'manager_lite', view: 'managers_view', manager_teammate_id: manager_teammate.id)
      
      expect(assigns(:current_spotlight)).to eq('manager_lite')
    end

    it 'sets the correct view type' do
      get organization_employees_path(organization, spotlight: 'manager_lite', view: 'managers_view', manager_teammate_id: manager_teammate.id)
      
      expect(assigns(:current_view)).to eq('managers_view')
    end

    it 'calculates manager_lite spotlight stats' do
      get organization_employees_path(organization, spotlight: 'manager_lite', view: 'managers_view', manager_teammate_id: manager_teammate.id)
      
      spotlight_stats = assigns(:spotlight_stats)
      expect(spotlight_stats).to be_present
      expect(spotlight_stats).to include(:total_teammates)
      expect(spotlight_stats).to include(:teammates_with_position_check_in)
      expect(spotlight_stats).to include(:teammates_with_assignment_check_in)
      expect(spotlight_stats).to include(:teammates_with_aspiration_check_in)
      expect(spotlight_stats).to include(:teammates_with_active_goal)
      expect(spotlight_stats).to include(:teammates_given_observation)
      expect(spotlight_stats).to include(:teammates_received_observation)
    end

    it 'renders the manager_lite spotlight partial' do
      get organization_employees_path(organization, spotlight: 'manager_lite', view: 'managers_view', manager_teammate_id: manager_teammate.id)
      
      expect(response).to be_successful
      expect(response.body).to include('Manager Lite')
      expect(response.body).to include('Total Teammates')
      expect(response.body).to include('Finalized Position Check-in')
      expect(response.body).to include('Finalized Assignment Check-in')
      expect(response.body).to include('Finalized Aspiration Check-in')
      expect(response.body).to include('Active Goal')
      expect(response.body).to include('Given Published Observation')
      expect(response.body).to include('Received Published Observation')
    end

    it 'renders the managers_view partial' do
      get organization_employees_path(organization, spotlight: 'manager_lite', view: 'managers_view', manager_teammate_id: manager_teammate.id)
      
      expect(response).to be_successful
      # The managers_view should render teammate cards
      expect(assigns(:filtered_and_paginated_teammates)).to be_present
    end

    it 'uses text-spice color classes in spotlight stats' do
      get organization_employees_path(organization, spotlight: 'manager_lite', view: 'managers_view', manager_teammate_id: manager_teammate.id)
      
      expect(response).to be_successful
      expect(response.body).to include('text-spice-1')
      expect(response.body).to include('text-spice-2')
      expect(response.body).to include('text-spice-3')
      expect(response.body).to include('text-spice-4')
      expect(response.body).to include('text-spice-5')
    end

    context 'with check-in data' do
      let!(:employment_tenure) do
        EmploymentTenure.find_by(teammate: direct_report1_teammate, company: organization) ||
        create(:employment_tenure, teammate: direct_report1_teammate, company: organization, manager_teammate: manager_teammate, started_at: 1.month.ago, ended_at: nil)
      end

      let!(:position_check_in) do
        create(:position_check_in,
          teammate: direct_report1_teammate,
          employment_tenure: employment_tenure,
          check_in_started_on: 30.days.ago,
          employee_completed_at: 25.days.ago,
          manager_completed_at: 20.days.ago,
          official_check_in_completed_at: 20.days.ago,
          official_rating: 2,
          finalized_by: manager
        )
      end

      let!(:assignment_check_in) do
        assignment = create(:assignment, company: organization)
        create(:assignment_check_in,
          teammate: direct_report1_teammate,
          assignment: assignment,
          check_in_started_on: 30.days.ago,
          employee_completed_at: 25.days.ago,
          manager_completed_at: 20.days.ago,
          official_check_in_completed_at: 20.days.ago,
          official_rating: 'meeting'
        )
      end

      let!(:aspiration_check_in) do
        aspiration = create(:aspiration, company: organization)
        create(:aspiration_check_in,
          teammate: direct_report1_teammate,
          aspiration: aspiration,
          check_in_started_on: 30.days.ago,
          employee_completed_at: 25.days.ago,
          manager_completed_at: 20.days.ago,
          official_check_in_completed_at: 20.days.ago,
          official_rating: 'meeting',
          finalized_by: manager
        )
      end

      it 'counts teammates with finalized position check-ins in last 90 days' do
        get organization_employees_path(organization, spotlight: 'manager_lite', view: 'managers_view', manager_teammate_id: manager_teammate.id)
        
        spotlight_stats = assigns(:spotlight_stats)
        expect(spotlight_stats[:teammates_with_position_check_in]).to be >= 1
      end

      it 'counts teammates with finalized assignment check-ins in last 90 days' do
        get organization_employees_path(organization, spotlight: 'manager_lite', view: 'managers_view', manager_teammate_id: manager_teammate.id)
        
        spotlight_stats = assigns(:spotlight_stats)
        expect(spotlight_stats[:teammates_with_assignment_check_in]).to be >= 1
      end

      it 'counts teammates with finalized aspiration check-ins in last 90 days' do
        get organization_employees_path(organization, spotlight: 'manager_lite', view: 'managers_view', manager_teammate_id: manager_teammate.id)
        
        spotlight_stats = assigns(:spotlight_stats)
        expect(spotlight_stats[:teammates_with_aspiration_check_in]).to be >= 1
      end
    end

    context 'with active goals' do
      let!(:goal) do
        Goal.create!(
          title: 'Test Goal',
          goal_type: 'quantitative_key_result',
          privacy_level: 'everyone_in_company',
          owner_type: 'CompanyTeammate',
          owner_id: direct_report1_teammate.id,
          creator: direct_report1_teammate,
          company: organization,
          started_at: 1.month.ago
        )
      end

      it 'counts teammates with active goals' do
        get organization_employees_path(organization, spotlight: 'manager_lite', view: 'managers_view', manager_teammate_id: manager_teammate.id)
        
        spotlight_stats = assigns(:spotlight_stats)
        expect(spotlight_stats[:teammates_with_active_goal]).to be >= 1
      end
    end

    context 'with observations' do
      let!(:observation_given) do
        create(:observation,
          observer: direct_report1,
          company: organization,
          observed_at: 10.days.ago,
          published_at: 10.days.ago,
          privacy_level: 'public_to_company',
          story: 'Test observation'
        )
      end

      let!(:observation_received) do
        obs = create(:observation,
          observer: manager,
          company: organization,
          observed_at: 10.days.ago,
          published_at: 10.days.ago,
          privacy_level: 'public_to_company',
          story: 'Test observation'
        )
        # Remove the default observee and add our specific one
        obs.observees.destroy_all
        obs.observees.create!(teammate: direct_report1_teammate)
        obs
      end

      it 'counts teammates who have given published observations in last 30 days' do
        get organization_employees_path(organization, spotlight: 'manager_lite', view: 'managers_view', manager_teammate_id: manager_teammate.id)
        
        spotlight_stats = assigns(:spotlight_stats)
        expect(spotlight_stats[:teammates_given_observation]).to be >= 1
      end

      it 'counts teammates who have received published observations in last 30 days' do
        get organization_employees_path(organization, spotlight: 'manager_lite', view: 'managers_view', manager_teammate_id: manager_teammate.id)
        
        spotlight_stats = assigns(:spotlight_stats)
        expect(spotlight_stats[:teammates_received_observation]).to be >= 1
      end
    end

    it 'defaults to manager_lite spotlight when manager_teammate_id is present and no spotlight is specified' do
      get organization_employees_path(organization, view: 'managers_view', manager_teammate_id: manager_teammate.id)
      
      expect(assigns(:current_spotlight)).to eq('manager_lite')
    end

    it 'handles empty direct reports gracefully' do
      # Remove all direct reports
      EmploymentTenure.where(manager_teammate: manager_teammate).destroy_all
      
      get organization_employees_path(organization, spotlight: 'manager_lite', view: 'managers_view', manager_teammate_id: manager_teammate.id)
      
      expect(response).to be_successful
      expect(assigns(:filtered_and_paginated_teammates)).to be_empty
      spotlight_stats = assigns(:spotlight_stats)
      expect(spotlight_stats[:total_teammates]).to eq(0)
    end
  end
end
