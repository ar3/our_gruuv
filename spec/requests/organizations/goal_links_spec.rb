require 'rails_helper'

RSpec.describe 'Organizations::GoalLinks', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { person.company_teammates.find_or_create_by!(organization: organization) { |t| t.first_employed_at = nil; t.last_terminated_at = nil } }
  let(:goal1) { create(:goal, creator: teammate, owner: teammate, title: 'Goal 1') }
  let(:goal2) { create(:goal, creator: teammate, owner: teammate, title: 'Goal 2') }
  let(:goal3) { create(:goal, creator: teammate, owner: teammate, title: 'Goal 3') }
  
  before do
    # Temporarily disable PaperTrail for request tests to avoid controller_info issues
    PaperTrail.enabled = false
    teammate # Ensure teammate exists before signing in
    sign_in_as_teammate_for_request(person, organization)
  end
  
  after do
    # Re-enable PaperTrail after tests
    PaperTrail.enabled = true
  end

  describe 'GET new_outgoing_link' do
    it 'returns success' do
      get new_outgoing_link_organization_goal_goal_links_path(organization, goal1)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET choose_outgoing_link' do
    it 'returns success' do
      get choose_outgoing_link_organization_goal_goal_links_path(organization, goal1)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET associate_existing_outgoing' do
    it 'returns success' do
      get associate_existing_outgoing_organization_goal_goal_links_path(organization, goal1)
      expect(response).to have_http_status(:ok)
    end

    it 'excludes org-owned goals from list when parent goal is teammate-owned' do
      org_goal = create(:goal, creator: teammate, owner: organization, title: 'Company-wide initiative', goal_type: 'stepping_stone_activity', company: organization, privacy_level: 'everyone_in_company')
      get associate_existing_outgoing_organization_goal_goal_links_path(organization, goal1, goal_type: 'stepping_stone_activity')
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Company-wide initiative')
    end

    it 'includes selection toolbar and parent captions for candidate children' do
      create(:goal_link, parent: goal1, child: goal3)
      # goal2 is a candidate child of goal1; give it a different parent for caption context
      other_parent = create(:goal, creator: teammate, owner: teammate, title: 'Other parent context')
      create(:goal_link, parent: other_parent, child: goal2)

      get associate_existing_outgoing_organization_goal_goal_links_path(organization, goal1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('selection-toolbar')
      expect(response.body).to include('Search goals by title or parent')
      expect(response.body).to include('Other parent context')
      expect(response.body).to include(goal2.title)
    end
  end

  describe 'POST associate_existing_outgoing' do
    it 'creates child links and redirects to goal' do
      post associate_existing_outgoing_organization_goal_goal_links_path(organization, goal1),
           params: { goal_ids: [goal2.id] }
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(organization_goal_path(organization, goal1))
      follow_redirect!
      expect(response.body).to include('Goal link was successfully created')
      expect(GoalLink.find_by(parent: goal1, child: goal2)).to be_present
    end
  end

  describe 'GET new_incoming_link' do
    it 'returns success' do
      get new_incoming_link_organization_goal_goal_links_path(organization, goal1)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET choose_incoming_link' do
    it 'returns success' do
      get choose_incoming_link_organization_goal_goal_links_path(organization, goal1)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET associate_existing_incoming' do
    it 'returns success' do
      get associate_existing_incoming_organization_goal_goal_links_path(organization, goal1)
      expect(response).to have_http_status(:ok)
    end

    it 'includes page help about the teammate-parent hierarchy rule' do
      get associate_existing_incoming_organization_goal_goal_links_path(organization, goal1)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Hierarchy rule')
      expect(response.body).to include('cannot')
      expect(response.body).to include('teammate-owned')
    end

    it 'includes selection toolbar search and shows existing parent titles above candidates' do
      create(:goal_link, parent: goal3, child: goal2)

      get associate_existing_incoming_organization_goal_goal_links_path(organization, goal1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('selection-toolbar')
      expect(response.body).to include('Search goals by title or parent')
      expect(response.body).to include(goal3.title)
      expect(response.body).to include(goal2.title)
    end

    it 'lists company-visible department and team parents for a department child' do
      department = create(:department, company: organization)
      team = create(:team, company: organization, department: department)
      child = create(:goal, creator: teammate, company: organization, owner: department,
                     title: 'Dept child', privacy_level: 'everyone_in_company')
      create(:goal, creator: teammate, company: organization, owner: organization,
             title: 'Company parent visible', privacy_level: 'everyone_in_company')
      create(:goal, creator: teammate, company: organization, owner: department,
             title: 'Dept parent visible', privacy_level: 'everyone_in_company')
      create(:goal, creator: teammate, company: organization, owner: team,
             title: 'Team parent visible', privacy_level: 'everyone_in_company')
      create(:goal, creator: teammate, owner: teammate, title: 'Teammate should hide')

      get associate_existing_incoming_organization_goal_goal_links_path(organization, child)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Company parent visible')
      expect(response.body).to include('Dept parent visible')
      expect(response.body).to include('Team parent visible')
      expect(response.body).not_to include('Teammate should hide')
    end
  end

  describe 'POST associate_existing_incoming' do
    it 'creates parent links and redirects to goal' do
      post associate_existing_incoming_organization_goal_goal_links_path(organization, goal1),
           params: { goal_ids: [goal2.id] }
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(organization_goal_path(organization, goal1))
      follow_redirect!
      expect(response.body).to include('Goal link was successfully created')
      expect(GoalLink.find_by(parent: goal2, child: goal1)).to be_present
    end
  end
  
  describe 'DELETE /organizations/:organization_id/goals/:goal_id/goal_links/:id' do
    context 'with outgoing link' do
      let!(:goal_link) { create(:goal_link, parent: goal1, child: goal2) }
      
      it 'destroys the goal link' do
        expect {
          delete organization_goal_goal_link_path(organization, goal1, goal_link)
        }.to change(GoalLink, :count).by(-1)
      end
      
      it 'redirects to goal show page' do
        delete organization_goal_goal_link_path(organization, goal1, goal_link)
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_goal_path(organization, goal1))
      end
      
      it 'shows flash notice on success' do
        delete organization_goal_goal_link_path(organization, goal1, goal_link)
        
        follow_redirect!
        expect(response.body).to include('Goal link was successfully deleted.')
      end
      
      it 'deletes the link from database' do
        link_id = goal_link.id
        delete organization_goal_goal_link_path(organization, goal1, goal_link)
        
        expect(GoalLink.find_by(id: link_id)).to be_nil
      end
    end
    
    context 'with incoming link' do
      let!(:goal_link) { create(:goal_link, parent: goal2, child: goal1) }
      
      it 'destroys the goal link' do
        expect {
          delete organization_goal_goal_link_path(organization, goal1, goal_link)
        }.to change(GoalLink, :count).by(-1)
      end
      
      it 'redirects to goal show page' do
        delete organization_goal_goal_link_path(organization, goal1, goal_link)
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_goal_path(organization, goal1))
      end
      
      it 'shows flash notice on success' do
        delete organization_goal_goal_link_path(organization, goal1, goal_link)
        
        follow_redirect!
        expect(response.body).to include('Goal link was successfully deleted.')
      end
      
      it 'deletes the link from database' do
        link_id = goal_link.id
        delete organization_goal_goal_link_path(organization, goal1, goal_link)
        
        expect(GoalLink.find_by(id: link_id)).to be_nil
      end
    end
    
    context 'with both link directions' do
      let!(:outgoing_link) { create(:goal_link, parent: goal1, child: goal2) }
      let!(:incoming_link) { create(:goal_link, parent: goal3, child: goal1) }
      
      it 'can delete outgoing link' do
        expect {
          delete organization_goal_goal_link_path(organization, goal1, outgoing_link)
        }.to change(GoalLink, :count).by(-1)
        
        expect(GoalLink.find_by(id: outgoing_link.id)).to be_nil
        expect(GoalLink.find_by(id: incoming_link.id)).to be_present
      end
      
      it 'can delete incoming link' do
        expect {
          delete organization_goal_goal_link_path(organization, goal1, incoming_link)
        }.to change(GoalLink, :count).by(-1)
        
        expect(GoalLink.find_by(id: incoming_link.id)).to be_nil
        expect(GoalLink.find_by(id: outgoing_link.id)).to be_present
      end
    end
    
    context 'when user is not authorized' do
      let!(:goal_link) { create(:goal_link, parent: goal1, child: goal2) }
      let(:other_person) { create(:person) }
      let(:other_teammate) { other_person.company_teammates.find_or_create_by!(organization: organization) { |t| t.first_employed_at = nil; t.last_terminated_at = nil } }
      
      before do
        other_teammate # Ensure teammate exists before signing in
        # Sign in as different user who doesn't own the goal
        sign_in_as_teammate_for_request(other_person, organization)
      end
      
      it 'denies access and does not delete link' do
        link_id = goal_link.id
        
        delete organization_goal_goal_link_path(organization, goal1, goal_link)
        
        expect(response).to have_http_status(:redirect)
        expect(GoalLink.find_by(id: link_id)).to be_present
      end
    end
    
    context 'when link does not exist' do
      it 'redirects with error message' do
        fake_link_id = 99999
        
        delete organization_goal_goal_link_path(organization, goal1, fake_link_id)
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_goal_path(organization, goal1))
        
        follow_redirect!
        expect(response.body).to include('Goal link not found')
      end
      
      it 'does not change link count' do
        fake_link_id = 99999
        
        expect {
          delete organization_goal_goal_link_path(organization, goal1, fake_link_id)
        }.not_to change(GoalLink, :count)
      end
    end
  end
end

