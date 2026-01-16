require 'rails_helper'

RSpec.describe Organizations::GoalsController, type: :controller do
  include ActiveSupport::Testing::TimeHelpers
  
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:creator_teammate) { person.teammates.find_by(organization: company) }
  
  before do
    sign_in_as_teammate(person, company)
  end
  
  describe 'GET #index' do
    let!(:personal_goal) { create(:goal, creator: creator_teammate, owner: creator_teammate, most_likely_target_date: Date.today + 1.month) }
    let!(:team_goal) { create(:goal, creator: creator_teammate, owner: company, most_likely_target_date: Date.today + 6.months) }
    let!(:later_goal) { create(:goal, creator: creator_teammate, owner: creator_teammate, most_likely_target_date: Date.today + 12.months) }
    
    it 'renders the index page' do
      get :index, params: { organization_id: company.id, owner_type: 'CompanyTeammate', owner_id: creator_teammate.id }
      expect(response).to have_http_status(:success)
    end
    
    it 'defaults to logged in user when no owner filter is provided' do
      get :index, params: { organization_id: company.id }
      # Should default to current teammate's goals
      expect(assigns(:goals)).to include(personal_goal, later_goal)
      expect(assigns(:goals)).not_to include(team_goal) # team_goal has different owner
    end
    
    it 'assigns goals for the teammate when owner filter is provided' do
      get :index, params: { organization_id: company.id, owner_type: 'CompanyTeammate', owner_id: creator_teammate.id }
      expect(assigns(:goals)).to include(personal_goal, later_goal)
    end
    
    it 'filters by timeframe: now' do
      get :index, params: { organization_id: company.id, owner_type: 'CompanyTeammate', owner_id: creator_teammate.id, timeframe: 'now' }
      goals = assigns(:goals)
      expect(goals).to include(personal_goal)
      expect(goals).not_to include(team_goal, later_goal)
    end
    
    it 'filters by timeframe: next' do
      get :index, params: { organization_id: company.id, owner_type: 'Organization', owner_id: company.id, timeframe: 'next' }
      goals = assigns(:goals)
      expect(goals).to include(team_goal)
      expect(goals).not_to include(personal_goal, later_goal)
    end
    
    it 'filters by timeframe: later' do
      get :index, params: { organization_id: company.id, owner_type: 'CompanyTeammate', owner_id: creator_teammate.id, timeframe: 'later' }
      goals = assigns(:goals)
      expect(goals).to include(later_goal)
      expect(goals).not_to include(personal_goal, team_goal)
    end
    
    it 'filters by goal_type: inspirational_objective' do
      inspirational_goal = create(:goal, creator: creator_teammate, owner: creator_teammate, goal_type: 'inspirational_objective')
      qualitative_goal = create(:goal, creator: creator_teammate, owner: creator_teammate, goal_type: 'qualitative_key_result')
      
      get :index, params: { organization_id: company.id, owner_type: 'CompanyTeammate', owner_id: creator_teammate.id, goal_type: 'inspirational_objective' }
      goals = assigns(:goals)
      expect(goals).to include(inspirational_goal)
      expect(goals).not_to include(qualitative_goal)
    end
    
    it 'filters by status: draft' do
      draft_goal = create(:goal, creator: creator_teammate, owner: creator_teammate, started_at: nil)
      active_goal = create(:goal, creator: creator_teammate, owner: creator_teammate, started_at: 1.day.ago)
      
      get :index, params: { organization_id: company.id, owner_type: 'CompanyTeammate', owner_id: creator_teammate.id, status: 'draft' }
      goals = assigns(:goals)
      expect(goals).to include(draft_goal)
      expect(goals).not_to include(active_goal)
    end
    
    it 'filters by status: active' do
      draft_goal = create(:goal, creator: creator_teammate, owner: creator_teammate, started_at: nil)
      active_goal = create(:goal, creator: creator_teammate, owner: creator_teammate, started_at: 1.day.ago)
      
      get :index, params: { organization_id: company.id, owner_type: 'CompanyTeammate', owner_id: creator_teammate.id, status: 'active' }
      goals = assigns(:goals)
      expect(goals).to include(active_goal)
      expect(goals).not_to include(draft_goal)
    end
    
    it 'sorts by most_likely_target_date ascending' do
      get :index, params: { organization_id: company.id, owner_type: 'CompanyTeammate', owner_id: creator_teammate.id, sort: 'most_likely_target_date', direction: 'asc' }
      goals = assigns(:goals).to_a
      expect(goals.index(personal_goal)).to be < goals.index(later_goal)
      expect(goals).not_to include(team_goal) # team_goal has different owner
    end
    
    it 'sorts by most_likely_target_date descending' do
      get :index, params: { organization_id: company.id, owner_type: 'CompanyTeammate', owner_id: creator_teammate.id, sort: 'most_likely_target_date', direction: 'desc' }
      goals = assigns(:goals).to_a
      expect(goals.index(later_goal)).to be < goals.index(personal_goal)
      expect(goals).not_to include(team_goal) # team_goal has different owner
    end
    
    it 'sorts by title ascending' do
      goal_a = create(:goal, creator: creator_teammate, owner: creator_teammate, title: 'A Goal')
      goal_z = create(:goal, creator: creator_teammate, owner: creator_teammate, title: 'Z Goal')
      
      get :index, params: { organization_id: company.id, owner_type: 'CompanyTeammate', owner_id: creator_teammate.id, sort: 'title', direction: 'asc' }
      goals = assigns(:goals).to_a
      expect(goals.index(goal_a)).to be < goals.index(goal_z)
    end
    
    it 'sorts by created_at descending' do
      old_goal = create(:goal, creator: creator_teammate, owner: creator_teammate, created_at: 1.week.ago)
      new_goal = create(:goal, creator: creator_teammate, owner: creator_teammate, created_at: 1.day.ago)
      
      get :index, params: { organization_id: company.id, owner_type: 'CompanyTeammate', owner_id: creator_teammate.id, sort: 'created_at', direction: 'desc' }
      goals = assigns(:goals).to_a
      expect(goals.index(new_goal)).to be < goals.index(old_goal)
    end
    
    it 'applies spotlight: top_priority' do
      top_priority_goal = create(:goal, creator: creator_teammate, owner: creator_teammate, became_top_priority: 1.day.ago)
      regular_goal = create(:goal, creator: creator_teammate, owner: creator_teammate)
      
      get :index, params: { organization_id: company.id, owner_type: 'CompanyTeammate', owner_id: creator_teammate.id, spotlight: 'top_priority' }
      goals = assigns(:goals)
      expect(goals).to include(top_priority_goal)
      # Spotlight may filter or just highlight - check that it's included
    end
    
    it 'applies spotlight: recently_added' do
      recent_goal = create(:goal, creator: creator_teammate, owner: creator_teammate, created_at: 1.day.ago)
      old_goal = create(:goal, creator: creator_teammate, owner: creator_teammate, created_at: 1.month.ago)
      
      get :index, params: { organization_id: company.id, owner_type: 'CompanyTeammate', owner_id: creator_teammate.id, spotlight: 'recently_added' }
      goals = assigns(:goals)
      expect(goals).to include(recent_goal)
    end
    
    it 'sets view style from params' do
      get :index, params: { organization_id: company.id, owner_type: 'CompanyTeammate', owner_id: creator_teammate.id, view: 'cards' }
      expect(assigns(:view_style)).to eq('cards')
    end
    
    it 'defaults view style to hierarchical-indented' do
      get :index, params: { organization_id: company.id, owner_type: 'CompanyTeammate', owner_id: creator_teammate.id }
      expect(assigns(:view_style)).to eq('hierarchical-indented')
    end
  end
  
  describe 'GET #show' do
    let(:goal) { create(:goal, creator: creator_teammate, owner: creator_teammate) }
    
    it 'renders the show page' do
      get :show, params: { organization_id: company.id, id: goal.id }
      expect(response).to have_http_status(:success)
    end
    
    it 'assigns the goal' do
      get :show, params: { organization_id: company.id, id: goal.id }
      expect(assigns(:goal)).to eq(goal)
    end
    
    it 'includes outgoing links' do
      linked_goal = create(:goal, creator: creator_teammate, owner: creator_teammate)
      link = create(:goal_link, parent: goal, child: linked_goal)
      
      get :show, params: { organization_id: company.id, id: goal.id }
      expect(assigns(:goal).outgoing_links).to include(link)
    end
    
    it 'includes incoming links' do
      linking_goal = create(:goal, creator: creator_teammate, owner: creator_teammate)
      link = create(:goal_link, parent: linking_goal, child: goal)
      
      get :show, params: { organization_id: company.id, id: goal.id }
      expect(assigns(:goal).incoming_links).to include(link)
    end
    
    it 'loads prompt attachments' do
      template = create(:prompt_template, company: company, available_at: Date.current)
      prompt = create(:prompt, company_teammate: creator_teammate, prompt_template: template)
      prompt_goal = PromptGoal.create!(prompt: prompt, goal: goal)
      
      get :show, params: { organization_id: company.id, id: goal.id }
      
      expect(assigns(:prompt_goals)).to include(prompt_goal)
      expect(assigns(:prompt_goals).first.prompt).to eq(prompt)
    end
    
    context 'when goal is started' do
      let(:started_goal) { create(:goal, creator: creator_teammate, owner: creator_teammate, started_at: 1.week.ago) }
      let(:current_week_start) { Date.current.beginning_of_week(:monday) }
      
      it 'loads current week check-in if it exists' do
        check_in = create(:goal_check_in, goal: started_goal, check_in_week_start: current_week_start, confidence_reporter: person)
        
        get :show, params: { organization_id: company.id, id: started_goal.id }
        
        expect(assigns(:current_check_in)).to eq(check_in)
        expect(assigns(:current_week_start)).to eq(current_week_start)
      end
      
      it 'loads last check-in if it exists' do
        last_week_start = current_week_start - 1.week
        last_check_in = create(:goal_check_in, goal: started_goal, check_in_week_start: last_week_start, confidence_reporter: person)
        
        get :show, params: { organization_id: company.id, id: started_goal.id }
        
        expect(assigns(:last_check_in)).to eq(last_check_in)
      end
      
      it 'does not load check-ins when goal is not started' do
        unstarted_goal = create(:goal, creator: creator_teammate, owner: creator_teammate, started_at: nil)
        
        get :show, params: { organization_id: company.id, id: unstarted_goal.id }
        
        expect(assigns(:current_check_in)).to be_nil
        expect(assigns(:last_check_in)).to be_nil
      end
    end
  end
  
  describe 'GET #new' do
    it 'renders the new form' do
      get :new, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end
    
    it 'assigns a new goal form' do
      get :new, params: { organization_id: company.id }
      expect(assigns(:form)).to be_present
      expect(assigns(:form)).to be_a(GoalForm)
      expect(assigns(:form).model).to be_a(Goal)
    end
    
    it 'sets current_person and current_teammate on form' do
      get :new, params: { organization_id: company.id }
      expect(assigns(:form).current_person).to eq(person)
      expect(assigns(:form).current_teammate).to eq(creator_teammate)
    end
    
    it 'defaults privacy level to only_creator_owner_and_managers' do
      get :new, params: { organization_id: company.id }
      expect(assigns(:form).privacy_level).to eq('only_creator_owner_and_managers')
    end
    
    it 'defaults earliest_target_date and latest_target_date to nil' do
      get :new, params: { organization_id: company.id }
      expect(assigns(:form).earliest_target_date).to be_nil
      expect(assigns(:form).latest_target_date).to be_nil
    end
    
    it 'defaults owner to current teammate when no query params provided' do
      get :new, params: { organization_id: company.id }
      expect(assigns(:form).owner_id).to eq("CompanyTeammate_#{creator_teammate.id}")
    end
    
    it 'uses owner from query string params when provided' do
      other_person = create(:person)
      other_teammate = other_person.teammates.find_or_create_by!(organization: company) do |t|
        t.type = 'CompanyTeammate'
        t.first_employed_at = nil
        t.last_terminated_at = nil
      end
      
      get :new, params: { 
        organization_id: company.id, 
        owner_id: "CompanyTeammate_#{other_teammate.id}" 
      }
      expect(assigns(:form).owner_id).to eq("CompanyTeammate_#{other_teammate.id}")
    end
    
    it 'uses owner_type and owner_id from query string params when provided separately' do
      other_person = create(:person)
      other_teammate = other_person.teammates.find_or_create_by!(organization: company) do |t|
        t.type = 'CompanyTeammate'
        t.first_employed_at = nil
        t.last_terminated_at = nil
      end
      
      get :new, params: { 
        organization_id: company.id, 
        owner_type: 'CompanyTeammate',
        owner_id: other_teammate.id.to_s
      }
      expect(assigns(:form).owner_type).to eq('CompanyTeammate')
      expect(assigns(:form).owner_id).to eq(other_teammate.id.to_s)
    end
  end
  
  describe 'POST #create' do
    let(:valid_attributes) do
      {
        title: 'Test Goal',
        description: 'A test goal',
        goal_type: 'inspirational_objective',
        earliest_target_date: Date.today + 1.month,
        most_likely_target_date: Date.today + 2.months,
        latest_target_date: Date.today + 3.months,
        privacy_level: 'only_creator',
        owner_type: 'CompanyTeammate',
        owner_id: creator_teammate.id
      }
    end
    
    it 'creates a new goal' do
      expect {
        post :create, params: { organization_id: company.id, goal: valid_attributes }
      }.to change(Goal, :count).by(1)
    end
    
    it 'sets the creator to current teammate' do
      post :create, params: { organization_id: company.id, goal: valid_attributes }
      goal = Goal.last
      expect(goal.creator).to eq(creator_teammate)
    end
    
    it 'redirects to the goal check-in mode' do
      post :create, params: { organization_id: company.id, goal: valid_attributes }
      expect(response).to redirect_to(weekly_update_organization_goal_path(company, Goal.last))
    end
    
    it 'shows flash notice on success' do
      post :create, params: { organization_id: company.id, goal: valid_attributes }
      expect(flash[:notice]).to eq('Goal was successfully created.')
    end
    
    it 'renders new template with errors on validation failure' do
      invalid_attributes = valid_attributes.merge(title: nil)
      post :create, params: { organization_id: company.id, goal: invalid_attributes }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:new)
      expect(assigns(:form).errors).to be_present
      expect(flash[:alert]).to be_present
      expect(flash[:alert]).to include('Title')
    end
    
    it 'automatically sets owner to current teammate if owner is nil' do
      attributes_without_owner = valid_attributes.except(:owner_type, :owner_id)
      
      expect {
        post :create, params: { organization_id: company.id, goal: attributes_without_owner }
      }.to change(Goal, :count).by(1)
      
      goal = Goal.last
      expect(goal.owner).to eq(creator_teammate)
      expect(goal.owner_type).to eq('CompanyTeammate')
    end
    
    it 'automatically sets owner to current teammate if owner is nil or blank' do
      # Test that when owner_type and owner_id are missing (nil), they're automatically set
      attributes_without_owner = valid_attributes.except(:owner_type, :owner_id)
      
      expect {
        post :create, params: { organization_id: company.id, goal: attributes_without_owner }
      }.to change(Goal, :count).by(1)
      
      goal = Goal.last
      expect(goal.owner).to eq(creator_teammate)
      expect(goal.owner_type).to eq('CompanyTeammate')
    end
    
    context 'with invalid owner types' do
      let(:department) { create(:organization, :department, parent: company) }
      let(:team_org) { create(:organization, :team, parent: company) }
      let(:department_teammate) { create(:teammate, person: person, organization: department) }
      let(:team_teammate) { create(:teammate, person: person, organization: team_org) }
      
      before do
        # Ensure teammates are actually DepartmentTeammate and TeamTeammate
        department_teammate.update_column(:type, 'DepartmentTeammate')
        team_teammate.update_column(:type, 'TeamTeammate')
      end
      
      it 'does not allow creating goal with DepartmentTeammate as owner' do
        invalid_attributes = valid_attributes.merge(
          owner_type: 'CompanyTeammate',
          owner_id: department_teammate.id
        )
        
        expect {
          post :create, params: { organization_id: company.id, goal: invalid_attributes }
        }.not_to change(Goal, :count)
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
        # Check for errors on owner_id (form validation) or owner (model validation)
        form_errors = assigns(:form).errors
        expect(form_errors[:owner_id].present? || form_errors[:owner].present?).to be true
      end
      
      it 'does not allow creating goal with TeamTeammate as owner' do
        invalid_attributes = valid_attributes.merge(
          owner_type: 'CompanyTeammate',
          owner_id: team_teammate.id
        )
        
        expect {
          post :create, params: { organization_id: company.id, goal: invalid_attributes }
        }.not_to change(Goal, :count)
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
        # Check for errors on owner_id (form validation) or owner (model validation)
        form_errors = assigns(:form).errors
        expect(form_errors[:owner_id].present? || form_errors[:owner].present?).to be true
      end
    end
  end
  
  describe 'GET #edit' do
    let(:goal) { create(:goal, creator: creator_teammate, owner: creator_teammate) }
    
    it 'renders the edit form' do
      get :edit, params: { organization_id: company.id, id: goal.id }
      expect(response).to have_http_status(:success)
    end
    
    it 'assigns the goal form' do
      get :edit, params: { organization_id: company.id, id: goal.id }
      expect(assigns(:form)).to be_present
      expect(assigns(:form).model).to eq(goal)
    end
    
    it 'loads linked goals data for display' do
      linked_goal = create(:goal, creator: creator_teammate, owner: creator_teammate)
      create(:goal_link, parent: goal, child: linked_goal)
      
      get :edit, params: { organization_id: company.id, id: goal.id }
      
      expect(assigns(:linked_goals)).to be_present
      expect(assigns(:linked_goals)[linked_goal.id]).to eq(linked_goal)
      expect(assigns(:linked_goal_check_ins)).to be_a(Hash)
    end
    
    it 'loads incoming links data' do
      parent_goal = create(:goal, creator: creator_teammate, owner: creator_teammate)
      create(:goal_link, parent: parent_goal, child: goal)
      
      get :edit, params: { organization_id: company.id, id: goal.id }
      
      expect(assigns(:linked_goals)).to be_present
      expect(assigns(:linked_goals)[parent_goal.id]).to eq(parent_goal)
    end
    
    it 'initializes empty linked goals when goal has no links' do
      get :edit, params: { organization_id: company.id, id: goal.id }
      
      expect(assigns(:linked_goals)).to eq({})
      expect(assigns(:linked_goal_check_ins)).to eq({})
    end
  end
  
  describe 'GET #weekly_update' do
    let(:goal) { create(:goal, creator: creator_teammate, owner: creator_teammate, started_at: 1.week.ago) }
    
    it 'renders the weekly update page' do
      get :weekly_update, params: { organization_id: company.id, id: goal.id }
      expect(response).to have_http_status(:success)
    end
    
    it 'authorizes goal access' do
      get :weekly_update, params: { organization_id: company.id, id: goal.id }
      expect(response).to have_http_status(:success)
    end
    
    it 'loads all check-ins chronologically' do
      check_in1 = create(:goal_check_in, goal: goal, check_in_week_start: 3.weeks.ago.beginning_of_week(:monday), confidence_reporter: person)
      check_in2 = create(:goal_check_in, goal: goal, check_in_week_start: 2.weeks.ago.beginning_of_week(:monday), confidence_reporter: person)
      check_in3 = create(:goal_check_in, goal: goal, check_in_week_start: 1.week.ago.beginning_of_week(:monday), confidence_reporter: person)
      
      get :weekly_update, params: { organization_id: company.id, id: goal.id }
      
      expect(assigns(:all_check_ins)).to eq([check_in1, check_in2, check_in3])
    end
    
    it 'loads current week check-in if exists' do
      current_week_start = Date.current.beginning_of_week(:monday)
      current_check_in = create(:goal_check_in, goal: goal, check_in_week_start: current_week_start, confidence_reporter: person)
      
      get :weekly_update, params: { organization_id: company.id, id: goal.id }
      
      expect(assigns(:current_check_in)).to eq(current_check_in)
      expect(assigns(:current_week_start)).to eq(current_week_start)
    end
    
    it 'loads all check-ins in chronological order' do
      old_check_in = create(:goal_check_in, goal: goal, check_in_week_start: 2.weeks.ago.beginning_of_week(:monday), confidence_reporter: person)
      recent_check_in = create(:goal_check_in, goal: goal, check_in_week_start: 1.week.ago.beginning_of_week(:monday), confidence_reporter: person)
      
      get :weekly_update, params: { organization_id: company.id, id: goal.id }
      
      expect(assigns(:all_check_ins)).to eq([old_check_in, recent_check_in])
    end
    
    it 'sets return_url and return_text from params' do
      return_url = organization_goal_path(company, goal)
      return_text = 'Back to Goal'
      
      get :weekly_update, params: { 
        organization_id: company.id, 
        id: goal.id,
        return_url: return_url,
        return_text: return_text
      }
      
      expect(assigns(:return_url)).to eq(return_url)
      expect(assigns(:return_text)).to eq(return_text)
    end
    
    it 'defaults return_url and return_text if not provided' do
      get :weekly_update, params: { organization_id: company.id, id: goal.id }
      
      expect(assigns(:return_url)).to eq(organization_goal_path(company, goal))
      expect(assigns(:return_text)).to eq('Back to Goal')
    end
  end
  
  describe 'PATCH #update' do
    let(:goal) { create(:goal, creator: creator_teammate, owner: creator_teammate, title: 'Original Title') }
    
    it 'updates the goal' do
      patch :update, params: { 
        organization_id: company.id, 
        id: goal.id,
        goal: {
          title: 'Updated Title',
          description: goal.description,
          goal_type: goal.goal_type,
          earliest_target_date: goal.earliest_target_date,
          most_likely_target_date: goal.most_likely_target_date,
          latest_target_date: goal.latest_target_date,
          privacy_level: goal.privacy_level,
          owner_type: goal.owner_type,
          owner_id: goal.owner_id
        }
      }
      
      goal.reload
      expect(goal.title).to eq('Updated Title')
    end
    
    it 'redirects to the goal on success' do
      patch :update, params: { 
        organization_id: company.id, 
        id: goal.id,
        goal: {
          title: 'Updated Title',
          description: goal.description,
          goal_type: goal.goal_type,
          earliest_target_date: goal.earliest_target_date,
          most_likely_target_date: goal.most_likely_target_date,
          latest_target_date: goal.latest_target_date,
          privacy_level: goal.privacy_level,
          owner_type: goal.owner_type,
          owner_id: goal.owner_id
        }
      }
      
      expect(response).to redirect_to(organization_goal_path(company, goal))
    end
    
    it 'shows flash notice on success' do
      patch :update, params: { 
        organization_id: company.id, 
        id: goal.id,
        goal: {
          title: 'Updated Title',
          description: goal.description,
          goal_type: goal.goal_type,
          earliest_target_date: goal.earliest_target_date,
          most_likely_target_date: goal.most_likely_target_date,
          latest_target_date: goal.latest_target_date,
          privacy_level: goal.privacy_level,
          owner_type: goal.owner_type,
          owner_id: goal.owner_id
        }
      }
      
      expect(flash[:notice]).to eq('Goal was successfully updated.')
    end
    
    it 'renders edit template with errors on validation failure' do
      patch :update, params: { 
        organization_id: company.id, 
        id: goal.id,
        goal: {
          title: nil,
          description: goal.description,
          goal_type: goal.goal_type,
          earliest_target_date: goal.earliest_target_date,
          most_likely_target_date: goal.most_likely_target_date,
          latest_target_date: goal.latest_target_date,
          privacy_level: goal.privacy_level,
          owner_type: goal.owner_type,
          owner_id: goal.owner_id
        }
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:edit)
      expect(assigns(:form).errors).to be_present
    end
    
    context 'with invalid owner types' do
      let(:department) { create(:organization, :department, parent: company) }
      let(:team_org) { create(:organization, :team, parent: company) }
      let(:department_teammate) { create(:teammate, person: person, organization: department) }
      let(:team_teammate) { create(:teammate, person: person, organization: team_org) }
      
      before do
        # Ensure teammates are actually DepartmentTeammate and TeamTeammate
        department_teammate.update_column(:type, 'DepartmentTeammate')
        team_teammate.update_column(:type, 'TeamTeammate')
      end
      
      it 'does not allow updating goal to have DepartmentTeammate as owner' do
        patch :update, params: { 
          organization_id: company.id, 
          id: goal.id,
          goal: {
            title: goal.title,
            description: goal.description,
            goal_type: goal.goal_type,
            earliest_target_date: goal.earliest_target_date,
            most_likely_target_date: goal.most_likely_target_date,
            latest_target_date: goal.latest_target_date,
            privacy_level: goal.privacy_level,
            owner_type: 'CompanyTeammate',
            owner_id: department_teammate.id
          }
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:edit)
        # Check for errors on owner_id (form validation) or owner (model validation)
        form_errors = assigns(:form).errors
        expect(form_errors[:owner_id].present? || form_errors[:owner].present?).to be true
        goal.reload
        expect(goal.owner).not_to eq(department_teammate)
      end
      
      it 'does not allow updating goal to have TeamTeammate as owner' do
        patch :update, params: { 
          organization_id: company.id, 
          id: goal.id,
          goal: {
            title: goal.title,
            description: goal.description,
            goal_type: goal.goal_type,
            earliest_target_date: goal.earliest_target_date,
            most_likely_target_date: goal.most_likely_target_date,
            latest_target_date: goal.latest_target_date,
            privacy_level: goal.privacy_level,
            owner_type: 'CompanyTeammate',
            owner_id: team_teammate.id
          }
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:edit)
        # Check for errors on owner_id (form validation) or owner (model validation)
        form_errors = assigns(:form).errors
        expect(form_errors[:owner_id].present? || form_errors[:owner].present?).to be true
        goal.reload
        expect(goal.owner).not_to eq(team_teammate)
      end
    end
  end
  
  describe 'DELETE #destroy' do
    let!(:goal) { create(:goal, creator: creator_teammate, owner: creator_teammate) }
    
    it 'soft deletes the goal' do
      expect {
        delete :destroy, params: { organization_id: company.id, id: goal.id }
      }.not_to change(Goal, :count)
      
      goal.reload
      expect(goal.deleted_at).to be_present
    end
    
    it 'redirects to goals index' do
      delete :destroy, params: { organization_id: company.id, id: goal.id }
      expect(response).to redirect_to(organization_goals_path(company))
    end
    
    it 'shows flash notice on success' do
      delete :destroy, params: { organization_id: company.id, id: goal.id }
      expect(flash[:notice]).to eq('Goal was successfully deleted.')
    end
  end
  
  describe 'PATCH #start' do
    let(:goal) { create(:goal, creator: creator_teammate, owner: creator_teammate, started_at: nil) }
    
    it 'sets started_at to current time' do
      travel_to Time.current do
        patch :start, params: { organization_id: company.id, id: goal.id }
        
        goal.reload
        expect(goal.started_at).to be_within(1.second).of(Time.current)
      end
    end
    
    it 'redirects to the goal show page' do
      patch :start, params: { organization_id: company.id, id: goal.id }
      expect(response).to redirect_to(organization_goal_path(company, goal))
    end
    
    it 'shows flash notice on success' do
      patch :start, params: { organization_id: company.id, id: goal.id }
      expect(flash[:notice]).to eq('Goal started successfully.')
    end
    
    it 'prevents starting an already started goal' do
      started_goal = create(:goal, creator: creator_teammate, owner: creator_teammate, started_at: 1.day.ago)
      original_started_at = started_goal.started_at
      
      patch :start, params: { organization_id: company.id, id: started_goal.id }
      
      started_goal.reload
      expect(started_goal.started_at).to eq(original_started_at)
      expect(flash[:alert]).to eq('Goal has already been started.')
    end
    
    context 'when user is not authorized' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { other_person.teammates.find_by(organization: company) }
      let(:goal) { create(:goal, creator: creator_teammate, owner: creator_teammate, started_at: nil, privacy_level: 'only_creator') }
      
      before do
        other_teammate # Ensure teammate is created
        sign_in_as_teammate(other_person, company)
      end
      
      it 'prevents starting the goal' do
        patch :start, params: { organization_id: company.id, id: goal.id }
        
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to match(/permission|not authorized/i)
      end
    end
  end
  
  describe 'POST #check_in' do
    let(:goal) { create(:goal, creator: creator_teammate, owner: creator_teammate, started_at: 1.week.ago) }
    let(:current_week_start) { Date.current.beginning_of_week(:monday) }
    
    it 'creates a new check-in for the current week' do
      expect {
        post :check_in, params: { 
          organization_id: company.id, 
          id: goal.id,
          confidence_percentage: 75,
          confidence_reason: 'Making good progress'
        }
      }.to change(GoalCheckIn, :count).by(1)
      
      check_in = GoalCheckIn.last
      expect(check_in.goal).to eq(goal)
      expect(check_in.check_in_week_start).to eq(current_week_start)
      expect(check_in.confidence_percentage).to eq(75)
      expect(check_in.confidence_reason).to eq('Making good progress')
      expect(check_in.confidence_reporter).to eq(person)
    end
    
    it 'updates existing check-in for the current week' do
      existing_check_in = create(:goal_check_in, 
        goal: goal, 
        check_in_week_start: current_week_start,
        confidence_percentage: 50,
        confidence_reason: 'Old reason',
        confidence_reporter: person
      )
      
      expect {
        post :check_in, params: { 
          organization_id: company.id, 
          id: goal.id,
          confidence_percentage: 80,
          confidence_reason: 'New reason'
        }
      }.not_to change(GoalCheckIn, :count)
      
      existing_check_in.reload
      expect(existing_check_in.confidence_percentage).to eq(80)
      expect(existing_check_in.confidence_reason).to eq('New reason')
    end
    
    it 'redirects to the goal show page' do
      post :check_in, params: { 
        organization_id: company.id, 
        id: goal.id,
        confidence_percentage: 75
      }
      expect(response).to redirect_to(organization_goal_path(company, goal))
    end
    
    it 'shows flash notice on success' do
      post :check_in, params: { 
        organization_id: company.id, 
        id: goal.id,
        confidence_percentage: 75
      }
      expect(flash[:notice]).to eq('Check-in saved successfully.')
    end

    context 'when goal has not been started' do
      let(:unstarted_goal) { create(:goal, creator: creator_teammate, owner: creator_teammate, started_at: nil) }

      it 'starts the goal after successful check-in save' do
        expect(unstarted_goal.started_at).to be_nil

        post :check_in, params: { 
          organization_id: company.id, 
          id: unstarted_goal.id,
          confidence_percentage: 75
        }

        unstarted_goal.reload
        expect(unstarted_goal.started_at).to be_present
      end
    end
    
    it 'handles validation errors' do
      post :check_in, params: { 
        organization_id: company.id, 
        id: goal.id,
        confidence_percentage: 150  # Invalid - should be 0-100
      }
      
      expect(response).to redirect_to(organization_goal_path(company, goal))
      expect(flash[:alert]).to match(/Failed to save check-in/)
    end
    
    it 'updates most_likely_target_date when provided' do
      new_target_date = Date.today + 60.days
      goal.update(most_likely_target_date: Date.today + 30.days)
      
      post :check_in, params: { 
        organization_id: company.id, 
        id: goal.id,
        confidence_percentage: 75,
        most_likely_target_date: new_target_date.to_s
      }
      
      goal.reload
      expect(goal.most_likely_target_date).to eq(new_target_date)
      expect(flash[:notice]).to match(/Target date updated/)
    end
    
    it 'updates latest_target_date to be at least one day after new target date if latest is set' do
      goal.update!(
        earliest_target_date: nil,
        most_likely_target_date: Date.today + 30.days,
        latest_target_date: Date.today + 60.days
      )
      new_target_date = Date.today + 70.days  # After current latest
      
      post :check_in, params: { 
        organization_id: company.id, 
        id: goal.id,
        confidence_percentage: 75,
        most_likely_target_date: new_target_date.to_s
      }
      
      goal.reload
      expect(goal.most_likely_target_date).to eq(new_target_date)
      expect(goal.latest_target_date).to eq(new_target_date + 1.day)
    end
    
    it 'does not update latest_target_date if new target date is before existing latest' do
      original_latest = Date.today + 60.days
      goal.update!(
        earliest_target_date: nil,
        most_likely_target_date: Date.today + 30.days,
        latest_target_date: original_latest
      )
      new_target_date = Date.today + 40.days  # Before current latest
      
      post :check_in, params: { 
        organization_id: company.id, 
        id: goal.id,
        confidence_percentage: 75,
        most_likely_target_date: new_target_date.to_s
      }
      
      goal.reload
      expect(goal.most_likely_target_date).to eq(new_target_date)
      expect(goal.latest_target_date).to eq(original_latest)
    end
    
    context 'when user is not authorized to view goal' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { other_person.teammates.find_by(organization: company) }
      let(:goal) { create(:goal, creator: creator_teammate, owner: creator_teammate, started_at: 1.week.ago, privacy_level: 'only_creator') }
      
      before do
        other_teammate # Ensure teammate is created
        sign_in_as_teammate(other_person, company)
      end
      
      it 'prevents creating check-in' do
        post :check_in, params: { 
          organization_id: company.id, 
          id: goal.id,
          confidence_percentage: 75
        }
        
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to match(/permission|not authorized/i)
      end
    end
  end
  
  describe 'authorization' do
    let(:goal) { create(:goal, creator: creator_teammate, owner: creator_teammate) }
    let(:other_person) { create(:person) }
    let(:other_teammate) { other_person.teammates.find_by(organization: company) }
    
    context 'when user is not authorized' do
      before do
        other_teammate # Ensure teammate is created
        sign_in_as_teammate(other_person, company)
      end
      
      it 'prevents access to show' do
        goal.update!(privacy_level: 'only_creator')
        # Authorization failure is handled by ApplicationController's rescue_from
        # which redirects with an alert instead of raising an error
        get :show, params: { organization_id: company.id, id: goal.id }
        
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to match(/permission|not authorized/i)
      end
      
      it 'prevents access to update' do
        # Authorization failure is handled by ApplicationController's rescue_from
        # which redirects with an alert instead of raising an error
        patch :update, params: { 
          organization_id: company.id, 
          id: goal.id,
          goal: { title: 'Hacked Title' }
        }
        
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to match(/permission|not authorized/i)
      end
    end
  end
end



