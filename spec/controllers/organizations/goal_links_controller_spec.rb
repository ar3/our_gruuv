require 'rails_helper'

RSpec.describe Organizations::GoalLinksController, type: :controller do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:creator_teammate) { create(:teammate, person: person, organization: company) }
  let(:goal1) { create(:goal, creator: creator_teammate, owner: person) }
  let(:goal2) { create(:goal, creator: creator_teammate, owner: person) }
  let(:goal3) { create(:goal, creator: creator_teammate, owner: person) }
  
  before do
    session[:current_person_id] = person.id
    creator_teammate # Ensure teammate is created
  end
  
  describe 'POST #create' do
    let(:valid_attributes) do
      {
        that_goal_id: goal2.id,
        link_type: 'this_blocks_that'
      }
    end
    
    it 'creates a new goal link' do
      expect {
        post :create, params: { 
          organization_id: company.id, 
          goal_id: goal1.id,
          goal_link: valid_attributes
        }
      }.to change(GoalLink, :count).by(1)
    end
    
    it 'creates link with correct attributes' do
      post :create, params: { 
        organization_id: company.id, 
        goal_id: goal1.id,
        goal_link: valid_attributes
      }
      
      link = GoalLink.last
      expect(link.this_goal).to eq(goal1)
      expect(link.that_goal).to eq(goal2)
      expect(link.link_type).to eq('this_blocks_that')
    end
    
    it 'handles metadata' do
      attributes_with_metadata = valid_attributes.merge(
        metadata: { notes: 'Important link', strength: 'high' }
      )
      
      post :create, params: { 
        organization_id: company.id, 
        goal_id: goal1.id,
        goal_link: attributes_with_metadata
      }
      
      link = GoalLink.last
      expect(link.metadata).to eq({ 'notes' => 'Important link', 'strength' => 'high' })
    end
    
    it 'redirects to goal show page on success' do
      post :create, params: { 
        organization_id: company.id, 
        goal_id: goal1.id,
        goal_link: valid_attributes
      }
      
      expect(response).to redirect_to(organization_goal_path(company, goal1))
    end
    
    it 'shows flash notice on success' do
      post :create, params: { 
        organization_id: company.id, 
        goal_id: goal1.id,
        goal_link: valid_attributes
      }
      
      expect(flash[:notice]).to eq('Goal link was successfully created.')
    end
    
    it 'prevents self-linking' do
      invalid_attributes = valid_attributes.merge(that_goal_id: goal1.id)
      
      expect {
        post :create, params: { 
          organization_id: company.id, 
          goal_id: goal1.id,
          goal_link: invalid_attributes
        }
      }.not_to change(GoalLink, :count)
      
      expect(response).to redirect_to(organization_goal_path(company, goal1))
      expect(flash[:alert]).to be_present
    end
    
    it 'prevents circular dependencies' do
      # Create goal1 -> goal2
      create(:goal_link, this_goal: goal1, that_goal: goal2)
      
      # Try to create goal2 -> goal1 (circular)
      invalid_attributes = {
        that_goal_id: goal1.id,
        link_type: 'this_blocks_that'
      }
      
      expect {
        post :create, params: { 
          organization_id: company.id, 
          goal_id: goal2.id,
          goal_link: invalid_attributes
        }
      }.not_to change(GoalLink, :count)
      
      expect(response).to redirect_to(organization_goal_path(company, goal2))
      expect(flash[:alert]).to be_present
    end
    
    it 'prevents duplicate links' do
      # Create existing link
      create(:goal_link, this_goal: goal1, that_goal: goal2, link_type: 'this_blocks_that')
      
      expect {
        post :create, params: { 
          organization_id: company.id, 
          goal_id: goal1.id,
          goal_link: valid_attributes
        }
      }.not_to change(GoalLink, :count)
      
      expect(response).to redirect_to(organization_goal_path(company, goal1))
      expect(flash[:alert]).to be_present
    end
    
    it 'handles JSON requests' do
      post :create, params: { 
        organization_id: company.id, 
        goal_id: goal1.id,
        goal_link: valid_attributes
      }, format: :json
      
      expect(response.content_type).to include('application/json')
      expect(JSON.parse(response.body)).to have_key('errors')
    end
  end
  
  describe 'DELETE #destroy' do
    let!(:goal_link) { create(:goal_link, this_goal: goal1, that_goal: goal2) }
    
    it 'destroys the goal link' do
      expect {
        delete :destroy, params: { 
          organization_id: company.id, 
          goal_id: goal1.id, 
          id: goal_link.id 
        }
      }.to change(GoalLink, :count).by(-1)
    end
    
    it 'redirects to goal show page' do
      delete :destroy, params: { 
        organization_id: company.id, 
        goal_id: goal1.id, 
        id: goal_link.id 
      }
      
      expect(response).to redirect_to(organization_goal_path(company, goal1))
    end
    
    it 'shows flash notice on success' do
      delete :destroy, params: { 
        organization_id: company.id, 
        goal_id: goal1.id, 
        id: goal_link.id 
      }
      
      expect(flash[:notice]).to eq('Goal link was successfully deleted.')
    end
    
    it 'only allows deleting outgoing links from the goal' do
      incoming_link = create(:goal_link, this_goal: goal2, that_goal: goal1)
      
      expect {
        delete :destroy, params: { 
          organization_id: company.id, 
          goal_id: goal1.id, 
          id: incoming_link.id 
        }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
  
  describe 'authorization' do
    let(:other_person) { create(:person) }
    let(:other_teammate) { create(:teammate, person: other_person, organization: company) }
    let(:other_goal) { create(:goal, creator: other_teammate, owner: other_person) }
    let(:goal_link) { build(:goal_link, this_goal: other_goal, that_goal: goal1) }
    
    context 'when user cannot edit the goal' do
      before do
        session[:current_person_id] = person.id
        other_goal.update!(privacy_level: 'only_creator')
      end
      
      it 'prevents creating a link' do
        expect {
          post :create, params: { 
            organization_id: company.id, 
            goal_id: other_goal.id,
            goal_link: { that_goal_id: goal1.id, link_type: 'this_blocks_that' }
          }
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end
end


