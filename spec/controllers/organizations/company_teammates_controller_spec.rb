require 'rails_helper'

RSpec.describe Organizations::CompanyTeammatesController, type: :controller do
  let(:organization) { create(:organization, :company) }
  let(:manager) { create(:person) }
  let(:employee) { create(:person) }

  before do
    # Set up organization access for manager
    manager_teammate = create(:teammate, person: manager, organization: organization, can_manage_employment: true)
    # Set up organization access for employee
    employee_teammate = create(:teammate, person: employee, organization: organization)
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
        employee_teammate = employee.teammates.find_by(organization: organization)
        get :internal, params: { organization_id: organization.id, id: employee_teammate.id }
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:internal)
      end

      it 'assigns the correct instance variables' do
        employee_teammate = employee.teammates.find_by(organization: organization)
        get :internal, params: { organization_id: organization.id, id: employee_teammate.id }
        
        expect(assigns(:teammate)).to eq(employee_teammate)
        expect(assigns(:current_organization)).to be_a(Organization).and have_attributes(id: organization.id)
        expect(assigns(:employment_tenures)).to be_present
        expect(assigns(:teammates)).to be_present
      end

      it 'assigns active employment tenure details' do
        employee_teammate = employee.teammates.find_by(organization: organization)
        # Use existing employment tenure from before block, or create one if none exists
        employment_tenure = employee_teammate.employment_tenures.where(company: organization).first
        if employment_tenure.nil?
          employment_tenure = create(:employment_tenure, teammate: employee_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        end
        employee_teammate.update!(first_employed_at: 1.year.ago)
        
        get :internal, params: { organization_id: organization.id, id: employee_teammate.id }
        
        expect(assigns(:active_employment_tenure)).to eq(employment_tenure)
        expect(assigns(:earliest_start_date)).to be_present
      end

      it 'assigns active departments and teams' do
        employee_teammate = employee.teammates.find_by(organization: organization)
        department = create(:organization, :department, parent: organization)
        team = create(:organization, :team, parent: organization)
        create(:teammate, person: employee, organization: department)
        create(:teammate, person: employee, organization: team)
        
        get :internal, params: { organization_id: organization.id, id: employee_teammate.id }
        
        expect(assigns(:active_departments_and_teams)).to be_present
        expect(assigns(:active_departments_and_teams).count).to eq(2)
      end

      it 'assigns observations as observee' do
        employee_teammate = employee.teammates.find_by(organization: organization)
        
        get :internal, params: { organization_id: organization.id, id: employee_teammate.id }
        
        # Verify the instance variable is assigned and is an ActiveRecord relation
        observations = assigns(:observations_as_observee)
        expect(observations).to be_a(ActiveRecord::Relation)
        expect(observations.model).to eq(Observation)
      end

      it 'assigns observations as observer' do
        employee_teammate = employee.teammates.find_by(organization: organization)
        observation = create(:observation, observer: employee, company: organization, privacy_level: 'public_to_company', published_at: Time.current)
        
        get :internal, params: { organization_id: organization.id, id: employee_teammate.id }
        
        expect(assigns(:observations_as_observer)).to include(observation)
      end

      it 'assigns public goals with last check-in' do
        employee_teammate = employee.teammates.find_by(organization: organization)
        goal = create(:goal, creator: employee_teammate, owner: employee_teammate, company: organization, privacy_level: 'everyone_in_company', started_at: 1.month.ago, deleted_at: nil, completed_at: nil)
        check_in = create(:goal_check_in, goal: goal, confidence_reporter: employee, check_in_week_start: 1.week.ago.beginning_of_week(:monday))
        
        get :internal, params: { organization_id: organization.id, id: employee_teammate.id }
        
        expect(assigns(:public_goals)).to include(goal)
        # Find the goal in the assigned collection to check its instance variable
        assigned_goal = assigns(:public_goals).find { |g| g.id == goal.id }
        last_check_in = assigned_goal.instance_variable_get(:@last_check_in)
        expect(last_check_in).to eq(check_in)
      end
    end
  end
end








