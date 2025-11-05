require 'rails_helper'

RSpec.describe Organizations::GoalsController, type: :controller do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:creator_teammate) { create(:teammate, person: person, organization: company) }
  
  before do
    session[:current_person_id] = person.id
    creator_teammate # Ensure teammate is created
  end
  
  describe 'GET #index' do
    let!(:personal_goal) { create(:goal, creator: creator_teammate, owner: person, most_likely_target_date: Date.today + 1.month) }
    let!(:team_goal) { create(:goal, creator: creator_teammate, owner: company, most_likely_target_date: Date.today + 6.months) }
    let!(:later_goal) { create(:goal, creator: creator_teammate, owner: person, most_likely_target_date: Date.today + 12.months) }
    
    it 'renders the index page' do
      get :index, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end
    
    it 'assigns goals for the teammate' do
      get :index, params: { organization_id: company.id }
      expect(assigns(:goals)).to include(personal_goal, team_goal, later_goal)
    end
    
    it 'filters by timeframe: now' do
      get :index, params: { organization_id: company.id, timeframe: 'now' }
      goals = assigns(:goals)
      expect(goals).to include(personal_goal)
      expect(goals).not_to include(team_goal, later_goal)
    end
    
    it 'filters by timeframe: next' do
      get :index, params: { organization_id: company.id, timeframe: 'next' }
      goals = assigns(:goals)
      expect(goals).to include(team_goal)
      expect(goals).not_to include(personal_goal, later_goal)
    end
    
    it 'filters by timeframe: later' do
      get :index, params: { organization_id: company.id, timeframe: 'later' }
      goals = assigns(:goals)
      expect(goals).to include(later_goal)
      expect(goals).not_to include(personal_goal, team_goal)
    end
    
    it 'filters by goal_type: inspirational_objective' do
      inspirational_goal = create(:goal, creator: creator_teammate, owner: person, goal_type: 'inspirational_objective')
      qualitative_goal = create(:goal, creator: creator_teammate, owner: person, goal_type: 'qualitative_key_result')
      
      get :index, params: { organization_id: company.id, goal_type: 'inspirational_objective' }
      goals = assigns(:goals)
      expect(goals).to include(inspirational_goal)
      expect(goals).not_to include(qualitative_goal)
    end
    
    it 'filters by status: draft' do
      draft_goal = create(:goal, creator: creator_teammate, owner: person, started_at: nil)
      active_goal = create(:goal, creator: creator_teammate, owner: person, started_at: 1.day.ago)
      
      get :index, params: { organization_id: company.id, status: 'draft' }
      goals = assigns(:goals)
      expect(goals).to include(draft_goal)
      expect(goals).not_to include(active_goal)
    end
    
    it 'filters by status: active' do
      draft_goal = create(:goal, creator: creator_teammate, owner: person, started_at: nil)
      active_goal = create(:goal, creator: creator_teammate, owner: person, started_at: 1.day.ago)
      
      get :index, params: { organization_id: company.id, status: 'active' }
      goals = assigns(:goals)
      expect(goals).to include(active_goal)
      expect(goals).not_to include(draft_goal)
    end
    
    it 'sorts by most_likely_target_date ascending' do
      get :index, params: { organization_id: company.id, sort: 'most_likely_target_date', direction: 'asc' }
      goals = assigns(:goals).to_a
      expect(goals.index(personal_goal)).to be < goals.index(team_goal)
      expect(goals.index(team_goal)).to be < goals.index(later_goal)
    end
    
    it 'sorts by most_likely_target_date descending' do
      get :index, params: { organization_id: company.id, sort: 'most_likely_target_date', direction: 'desc' }
      goals = assigns(:goals).to_a
      expect(goals.index(later_goal)).to be < goals.index(team_goal)
      expect(goals.index(team_goal)).to be < goals.index(personal_goal)
    end
    
    it 'sorts by title ascending' do
      goal_a = create(:goal, creator: creator_teammate, owner: person, title: 'A Goal')
      goal_z = create(:goal, creator: creator_teammate, owner: person, title: 'Z Goal')
      
      get :index, params: { organization_id: company.id, sort: 'title', direction: 'asc' }
      goals = assigns(:goals).to_a
      expect(goals.index(goal_a)).to be < goals.index(goal_z)
    end
    
    it 'sorts by created_at descending' do
      old_goal = create(:goal, creator: creator_teammate, owner: person, created_at: 1.week.ago)
      new_goal = create(:goal, creator: creator_teammate, owner: person, created_at: 1.day.ago)
      
      get :index, params: { organization_id: company.id, sort: 'created_at', direction: 'desc' }
      goals = assigns(:goals).to_a
      expect(goals.index(new_goal)).to be < goals.index(old_goal)
    end
    
    it 'applies spotlight: top_priority' do
      top_priority_goal = create(:goal, creator: creator_teammate, owner: person, became_top_priority: 1.day.ago)
      regular_goal = create(:goal, creator: creator_teammate, owner: person)
      
      get :index, params: { organization_id: company.id, spotlight: 'top_priority' }
      goals = assigns(:goals)
      expect(goals).to include(top_priority_goal)
      # Spotlight may filter or just highlight - check that it's included
    end
    
    it 'applies spotlight: recently_added' do
      recent_goal = create(:goal, creator: creator_teammate, owner: person, created_at: 1.day.ago)
      old_goal = create(:goal, creator: creator_teammate, owner: person, created_at: 1.month.ago)
      
      get :index, params: { organization_id: company.id, spotlight: 'recently_added' }
      goals = assigns(:goals)
      expect(goals).to include(recent_goal)
    end
    
    it 'sets view style from params' do
      get :index, params: { organization_id: company.id, view: 'cards' }
      expect(assigns(:view_style)).to eq('cards')
    end
    
    it 'defaults view style to table' do
      get :index, params: { organization_id: company.id }
      expect(assigns(:view_style)).to eq('table')
    end
  end
  
  describe 'GET #show' do
    let(:goal) { create(:goal, creator: creator_teammate, owner: person) }
    
    it 'renders the show page' do
      get :show, params: { organization_id: company.id, id: goal.id }
      expect(response).to have_http_status(:success)
    end
    
    it 'assigns the goal' do
      get :show, params: { organization_id: company.id, id: goal.id }
      expect(assigns(:goal)).to eq(goal)
    end
    
    it 'includes outgoing links' do
      linked_goal = create(:goal, creator: creator_teammate, owner: person)
      link = create(:goal_link, this_goal: goal, that_goal: linked_goal)
      
      get :show, params: { organization_id: company.id, id: goal.id }
      expect(assigns(:goal).outgoing_links).to include(link)
    end
    
    it 'includes incoming links' do
      linking_goal = create(:goal, creator: creator_teammate, owner: person)
      link = create(:goal_link, this_goal: linking_goal, that_goal: goal)
      
      get :show, params: { organization_id: company.id, id: goal.id }
      expect(assigns(:goal).incoming_links).to include(link)
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
        owner_type: 'Person',
        owner_id: person.id
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
    
    it 'redirects to the created goal' do
      post :create, params: { organization_id: company.id, goal: valid_attributes }
      expect(response).to redirect_to(organization_goal_path(company, Goal.last))
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
    end
  end
  
  describe 'GET #edit' do
    let(:goal) { create(:goal, creator: creator_teammate, owner: person) }
    
    it 'renders the edit form' do
      get :edit, params: { organization_id: company.id, id: goal.id }
      expect(response).to have_http_status(:success)
    end
    
    it 'assigns the goal form' do
      get :edit, params: { organization_id: company.id, id: goal.id }
      expect(assigns(:form)).to be_present
      expect(assigns(:form).model).to eq(goal)
    end
  end
  
  describe 'PATCH #update' do
    let(:goal) { create(:goal, creator: creator_teammate, owner: person, title: 'Original Title') }
    
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
  end
  
  describe 'DELETE #destroy' do
    let!(:goal) { create(:goal, creator: creator_teammate, owner: person) }
    
    it 'destroys the goal' do
      expect {
        delete :destroy, params: { organization_id: company.id, id: goal.id }
      }.to change(Goal, :count).by(-1)
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
  
  describe 'authorization' do
    let(:goal) { create(:goal, creator: creator_teammate, owner: person) }
    let(:other_person) { create(:person) }
    let(:other_teammate) { create(:teammate, person: other_person, organization: company) }
    
    context 'when user is not authorized' do
      before do
        session[:current_person_id] = other_person.id
      end
      
      it 'prevents access to show' do
        goal.update!(privacy_level: 'only_creator')
        expect {
          get :show, params: { organization_id: company.id, id: goal.id }
        }.to raise_error(Pundit::NotAuthorizedError)
      end
      
      it 'prevents access to update' do
        expect {
          patch :update, params: { 
            organization_id: company.id, 
            id: goal.id,
            goal: { title: 'Hacked Title' }
          }
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end
end



