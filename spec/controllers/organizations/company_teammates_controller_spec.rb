require 'rails_helper'

RSpec.describe Organizations::CompanyTeammatesController, type: :controller do
  let(:organization) { create(:organization) }
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
        create(:department, company: organization)
        create(:team, company: organization)
        # Note: With STI removed, teammates only belong to Organizations.
        # active_departments_and_teams is now empty (no department/team teammates).
        
        get :internal, params: { organization_id: organization.id, id: employee_teammate.id }
        
        expect(assigns(:active_departments_and_teams)).to eq([])
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

      it 'assigns active assignment tenures' do
        employee_teammate = employee.teammates.find_by(organization: organization)
        assignment = create(:assignment, company: organization)
        active_tenure = create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, started_at: 1.month.ago, ended_at: nil)
        # Create an inactive tenure to ensure only active ones are returned
        inactive_tenure = create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, started_at: 3.months.ago, ended_at: 2.months.ago)
        
        get :internal, params: { organization_id: organization.id, id: employee_teammate.id }
        
        expect(assigns(:active_assignment_tenures)).to include(active_tenure)
        expect(assigns(:active_assignment_tenures)).not_to include(inactive_tenure)
      end

      it 'only assigns assignment tenures for assignments in the current organization' do
        employee_teammate = employee.teammates.find_by(organization: organization)
        other_organization = create(:organization)
        assignment_in_org = create(:assignment, company: organization)
        assignment_in_other_org = create(:assignment, company: other_organization)
        tenure_in_org = create(:assignment_tenure, teammate: employee_teammate, assignment: assignment_in_org, started_at: 1.month.ago, ended_at: nil)
        tenure_in_other_org = create(:assignment_tenure, teammate: employee_teammate, assignment: assignment_in_other_org, started_at: 1.month.ago, ended_at: nil)
        
        get :internal, params: { organization_id: organization.id, id: employee_teammate.id }
        
        expect(assigns(:active_assignment_tenures)).to include(tenure_in_org)
        expect(assigns(:active_assignment_tenures)).not_to include(tenure_in_other_org)
      end

      it 'assigns empty array when no active assignment tenures exist' do
        employee_teammate = employee.teammates.find_by(organization: organization)
        
        get :internal, params: { organization_id: organization.id, id: employee_teammate.id }
        
        expect(assigns(:active_assignment_tenures)).to eq([])
      end

      it 'sorts assignment tenures by energy (highest first) then alphabetically' do
        employee_teammate = employee.teammates.find_by(organization: organization)
        
        # Create assignments with specific titles for alphabetical sorting
        assignment_alpha = create(:assignment, company: organization, title: 'Alpha Assignment')
        assignment_beta = create(:assignment, company: organization, title: 'Beta Assignment')
        assignment_charlie = create(:assignment, company: organization, title: 'Charlie Assignment')
        assignment_delta = create(:assignment, company: organization, title: 'Delta Assignment')
        
        # Create tenures with different energy levels
        # Higher energy should come first, then alpha for same energy
        tenure_low_energy = create(:assignment_tenure, teammate: employee_teammate, assignment: assignment_charlie, started_at: 1.month.ago, ended_at: nil, anticipated_energy_percentage: 10)
        tenure_high_energy = create(:assignment_tenure, teammate: employee_teammate, assignment: assignment_beta, started_at: 1.month.ago, ended_at: nil, anticipated_energy_percentage: 50)
        tenure_no_energy = create(:assignment_tenure, teammate: employee_teammate, assignment: assignment_delta, started_at: 1.month.ago, ended_at: nil, anticipated_energy_percentage: nil)
        tenure_same_high_energy = create(:assignment_tenure, teammate: employee_teammate, assignment: assignment_alpha, started_at: 1.month.ago, ended_at: nil, anticipated_energy_percentage: 50)
        
        get :internal, params: { organization_id: organization.id, id: employee_teammate.id }
        
        tenures = assigns(:active_assignment_tenures)
        
        # Expect order: Alpha (50%), Beta (50%), Charlie (10%), Delta (nil/0)
        # Same energy sorts alphabetically by assignment title
        expect(tenures[0]).to eq(tenure_same_high_energy)  # Alpha, 50%
        expect(tenures[1]).to eq(tenure_high_energy)        # Beta, 50%
        expect(tenures[2]).to eq(tenure_low_energy)         # Charlie, 10%
        expect(tenures[3]).to eq(tenure_no_energy)          # Delta, nil
      end
    end

    context 'when viewing inactive teammate (no active employment)' do
      let(:inactive_employee) { create(:person) }
      let(:inactive_employee_teammate) { create(:teammate, person: inactive_employee, organization: organization) }

      before do
        # Create past employment (ended)
        create(:employment_tenure, teammate: inactive_employee_teammate, company: organization, started_at: 2.years.ago, ended_at: 1.year.ago)
        inactive_employee_teammate.update!(first_employed_at: 2.years.ago, last_terminated_at: 1.year.ago)
        # Allow policy to permit viewing
        allow_any_instance_of(CompanyTeammatePolicy).to receive(:internal?).and_return(true)
      end

      it 'renders the internal page successfully' do
        get :internal, params: { organization_id: organization.id, id: inactive_employee_teammate.id }
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:internal)
      end

      it 'assigns the correct instance variables' do
        get :internal, params: { organization_id: organization.id, id: inactive_employee_teammate.id }
        
        expect(assigns(:teammate).id).to eq(inactive_employee_teammate.id)
        expect(assigns(:current_organization)).to be_a(Organization).and have_attributes(id: organization.id)
        expect(assigns(:employment_tenures)).to be_present
        expect(assigns(:teammates)).to be_present
      end

      it 'does not assign active employment tenure (none exists)' do
        get :internal, params: { organization_id: organization.id, id: inactive_employee_teammate.id }
        
        expect(assigns(:active_employment_tenure)).to be_nil
      end

      it 'assigns earliest start date from past employment' do
        get :internal, params: { organization_id: organization.id, id: inactive_employee_teammate.id }
        
        expect(assigns(:earliest_start_date)).to be_present
        expect(assigns(:earliest_start_date)).to eq(inactive_employee_teammate.first_employed_at)
      end
    end

    context 'when viewing teammate with no employment tenure' do
      let(:teammate_without_employment) { create(:person) }
      let(:teammate_without_employment_record) { create(:teammate, person: teammate_without_employment, organization: organization) }

      before do
        # Allow policy to permit viewing
        allow_any_instance_of(CompanyTeammatePolicy).to receive(:internal?).and_return(true)
      end

      it 'renders the internal page successfully' do
        get :internal, params: { organization_id: organization.id, id: teammate_without_employment_record.id }
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:internal)
      end

      it 'assigns the correct instance variables' do
        get :internal, params: { organization_id: organization.id, id: teammate_without_employment_record.id }
        
        expect(assigns(:teammate).id).to eq(teammate_without_employment_record.id)
        expect(assigns(:current_organization)).to be_a(Organization).and have_attributes(id: organization.id)
        expect(assigns(:employment_tenures)).to eq([])
        expect(assigns(:teammates)).to be_present
      end

      it 'does not assign active employment tenure' do
        get :internal, params: { organization_id: organization.id, id: teammate_without_employment_record.id }
        
        expect(assigns(:active_employment_tenure)).to be_nil
      end

      it 'does not assign earliest start date' do
        get :internal, params: { organization_id: organization.id, id: teammate_without_employment_record.id }
        
        expect(assigns(:earliest_start_date)).to be_nil
      end
    end
  end

  describe 'GET #highlights_points' do
    context 'when user is permitted' do
      before do
        allow_any_instance_of(CompanyTeammatePolicy).to receive(:view_highlights_points?).and_return(true)
      end

      it 'renders the highlights_points page successfully' do
        employee_teammate = employee.teammates.find_by(organization: organization)
        get :highlights_points, params: { organization_id: organization.id, id: employee_teammate.id }
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:highlights_points)
      end

      it 'assigns ledger, transactions, person and pagy' do
        employee_teammate = employee.teammates.find_by(organization: organization)
        get :highlights_points, params: { organization_id: organization.id, id: employee_teammate.id }
        expect(assigns(:teammate)).to eq(employee_teammate)
        expect(assigns(:person)).to eq(employee)
        expect(assigns(:ledger)).to be_a(HighlightsPointsLedger)
        expect(assigns(:ledger).company_teammate).to eq(employee_teammate)
        expect(assigns(:transactions)).to be_a(ActiveRecord::Relation)
        expect(assigns(:pagy)).to be_a(Pagy)
      end
    end

    context 'when user is not self and not in managerial hierarchy' do
      before do
        allow_any_instance_of(CompanyTeammatePolicy).to receive(:view_highlights_points?).and_return(false)
      end

      it 'denies access' do
        employee_teammate = employee.teammates.find_by(organization: organization)
        get :highlights_points, params: { organization_id: organization.id, id: employee_teammate.id }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'GET #permissions' do
    context 'when user has update_permission permissions' do
      before do
        allow_any_instance_of(CompanyTeammatePolicy).to receive(:update_permission?).and_return(true)
      end

      it 'renders the permissions page successfully' do
        employee_teammate = employee.teammates.find_by(organization: organization)
        get :permissions, params: { organization_id: organization.id, id: employee_teammate.id }
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:permissions)
        expect(response).to render_template(layout: 'overlay')
      end

      it 'assigns the correct instance variables' do
        employee_teammate = employee.teammates.find_by(organization: organization)
        get :permissions, params: { organization_id: organization.id, id: employee_teammate.id }
        
        expect(assigns(:teammate)).to eq(employee_teammate)
        expect(assigns(:return_url)).to eq(organization_company_teammate_path(organization, employee_teammate))
        expect(assigns(:return_text)).to eq("Back to Profile")
      end

      it 'assigns who has each permission' do
        employee_teammate = employee.teammates.find_by(organization: organization)
        manager_teammate = manager.teammates.find_by(organization: organization)
        
        # Create another teammate with employment management
        other_person = create(:person)
        other_teammate = create(:teammate, person: other_person, organization: organization, can_manage_employment: true)
        highlights_person = create(:person)
        highlights_teammate = create(:teammate, person: highlights_person, organization: organization, can_manage_highlights_rewards: true)
        
        get :permissions, params: { organization_id: organization.id, id: employee_teammate.id }
        
        expect(assigns(:who_has_employment_management)).to include(manager_teammate)
        expect(assigns(:who_has_employment_management)).to include(other_teammate)
        expect(assigns(:who_has_employment_management)).not_to include(employee_teammate)
        expect(assigns(:who_has_highlights_rewards_management)).to include(highlights_teammate)
        expect(assigns(:who_has_highlights_rewards_management)).not_to include(employee_teammate)
      end
    end

  end

  describe 'POST #update_permissions' do
    context 'when user has employment management permission' do
      before do
        # Manager already has can_manage_employment: true from before block
        # Ensure policy allows update
        allow_any_instance_of(CompanyTeammatePolicy).to receive(:update_permission?).and_return(true)
      end

      it 'redirects to profile page after successful save' do
        employee_teammate = employee.teammates.find_by(organization: organization)
        post :update_permissions, params: {
          organization_id: organization.id,
          id: employee_teammate.id,
          can_manage_employment: 'true',
          can_create_employment: 'false',
          can_manage_maap: 'true',
          can_manage_prompts: 'false',
          can_manage_departments_and_teams: 'true',
          can_customize_company: 'true',
          can_manage_highlights_rewards: 'true'
        }
        
        expect(response).to redirect_to(organization_company_teammate_path(organization, employee_teammate))
        expect(flash[:notice]).to eq('Permissions updated successfully.')
      end

      it 'updates all permissions at once' do
        employee_teammate = employee.teammates.find_by(organization: organization)
        employee_teammate.update!(
          can_manage_employment: false,
          can_create_employment: false,
          can_manage_maap: false,
          can_manage_prompts: false,
          can_manage_departments_and_teams: false,
          can_customize_company: false,
          can_manage_highlights_rewards: false
        )
        
        post :update_permissions, params: {
          organization_id: organization.id,
          id: employee_teammate.id,
          can_manage_employment: 'true',
          can_create_employment: 'true',
          can_manage_maap: 'false',
          can_manage_prompts: 'true',
          can_manage_departments_and_teams: 'false',
          can_customize_company: 'true',
          can_manage_highlights_rewards: 'true'
        }
        
        employee_teammate.reload
        expect(employee_teammate.can_manage_employment).to eq(true)
        expect(employee_teammate.can_create_employment).to eq(true)
        expect(employee_teammate.can_manage_maap).to eq(false)
        expect(employee_teammate.can_manage_prompts).to eq(true)
        expect(employee_teammate.can_manage_departments_and_teams).to eq(false)
        expect(employee_teammate.can_customize_company).to eq(true)
        expect(employee_teammate.can_manage_highlights_rewards).to eq(true)
      end

      it 'handles setting permissions to false' do
        employee_teammate = employee.teammates.find_by(organization: organization)
        employee_teammate.update!(
          can_manage_employment: true,
          can_create_employment: true,
          can_manage_maap: true,
          can_manage_prompts: true,
          can_manage_departments_and_teams: true,
          can_customize_company: true,
          can_manage_highlights_rewards: true
        )
        
        post :update_permissions, params: {
          organization_id: organization.id,
          id: employee_teammate.id,
          can_manage_employment: 'false',
          can_create_employment: 'false',
          can_manage_maap: 'false',
          can_manage_prompts: 'false',
          can_manage_departments_and_teams: 'false',
          can_customize_company: 'false',
          can_manage_highlights_rewards: 'false'
        }
        
        employee_teammate.reload
        expect(employee_teammate.can_manage_employment).to eq(false)
        expect(employee_teammate.can_create_employment).to eq(false)
        expect(employee_teammate.can_manage_maap).to eq(false)
        expect(employee_teammate.can_manage_prompts).to eq(false)
        expect(employee_teammate.can_manage_departments_and_teams).to eq(false)
        expect(employee_teammate.can_customize_company).to eq(false)
        expect(employee_teammate.can_manage_highlights_rewards).to eq(false)
      end
    end

    context 'when user does not have employment management permission' do
      let(:non_manager) { create(:person) }
      let(:non_manager_teammate) { create(:teammate, person: non_manager, organization: organization, can_manage_employment: false) }
      
      before do
        create(:employment_tenure, teammate: non_manager_teammate, company: organization)
        sign_in_as_teammate(non_manager, organization)
      end

      it 'redirects to permissions page with error message' do
        employee_teammate = employee.teammates.find_by(organization: organization)
        post :update_permissions, params: {
          organization_id: organization.id,
          id: employee_teammate.id,
          can_manage_employment: 'true'
        }
        
        expect(response).to redirect_to(permissions_organization_company_teammate_path(organization, employee_teammate))
        expect(flash[:alert]).to include('You do not have permission to update permissions')
      end

      it 'does not update permissions' do
        employee_teammate = employee.teammates.find_by(organization: organization)
        original_value = employee_teammate.can_manage_employment
        
        post :update_permissions, params: {
          organization_id: organization.id,
          id: employee_teammate.id,
          can_manage_employment: 'true'
        }
        
        employee_teammate.reload
        expect(employee_teammate.can_manage_employment).to eq(original_value)
      end
    end
  end
end








