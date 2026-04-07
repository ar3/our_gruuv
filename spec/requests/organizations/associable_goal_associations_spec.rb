# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Associable goal associations', type: :request do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:manager_teammate) do
    create(:teammate, :unassigned_employee, person: manager, organization: organization, can_manage_maap: true)
  end
  let(:goal) do
    create(
      :goal,
      company_id: organization.id,
      creator: manager_teammate,
      owner: manager_teammate,
      goal_type: 'inspirational_objective',
      most_likely_target_date: nil,
      earliest_target_date: nil,
      latest_target_date: nil
    )
  end

  before do
    PaperTrail.enabled = false
    manager_teammate
    sign_in_as_teammate_for_request(manager, organization)
  end

  after { PaperTrail.enabled = true }

  describe 'assignments' do
    let(:assignment) { create(:assignment, company: organization) }

    it 'GET manage_goals includes nested bulk example insert control' do
      get manage_goals_organization_assignment_path(organization, assignment)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Insert a 3-layer example')
      expect(response.body).to include('data-controller="bulk-goals-example"')
    end

    it 'POST creates a goal association' do
      expect do
        post organization_assignment_goal_associations_path(organization, assignment),
             params: { goal_ids: [goal.id], return_url: organization_assignment_path(organization, assignment) }
      end.to change { assignment.goal_associations.count }.by(1)

      expect(response).to redirect_to(organization_assignment_path(organization, assignment))
    end

    it 'POST preserves leading spaces in bulk_goal_titles so three nesting levels parse and link correctly' do
      bulk = <<~TEXT
        Objective O (L)
        * Key R (L)
            1. Act A (L)
      TEXT

      expect do
        post organization_assignment_goal_associations_path(organization, assignment),
             params: { bulk_goal_titles: bulk, return_url: organization_assignment_path(organization, assignment) }
      end.to change(Goal, :count).by(3)
        .and change(GoalLink, :count).by(2)

      obj = Goal.find_by!(title: 'Objective O (L)')
      kr = Goal.find_by!(title: '* Key R (L)')
      act = Goal.find_by!(title: '1. Act A (L)')
      expect(obj.goal_type).to eq('inspirational_objective')
      expect(GoalLink.exists?(parent: obj, child: kr)).to be true
      expect(GoalLink.exists?(parent: kr, child: act)).to be true
    end

    it 'DELETE removes a goal association' do
      ga = create(:goal_association, associable: assignment, goal: goal)
      expect do
        delete organization_assignment_goal_association_path(organization, assignment, ga),
               params: { return_url: organization_assignment_path(organization, assignment) }
      end.to change { assignment.goal_associations.count }.by(-1)
      expect(response).to redirect_to(organization_assignment_path(organization, assignment))
    end
  end

  describe 'abilities' do
    let(:ability) { create(:ability, company: organization) }

    it 'POST creates a goal association' do
      expect do
        post organization_ability_goal_associations_path(organization, ability),
             params: { goal_ids: [goal.id], return_url: organization_ability_path(organization, ability) }
      end.to change { ability.goal_associations.count }.by(1)
    end
  end

  describe 'aspirations' do
    let(:aspiration) { create(:aspiration, company: organization) }

    it 'POST creates a goal association' do
      expect do
        post organization_aspiration_goal_associations_path(organization, aspiration),
             params: { goal_ids: [goal.id], return_url: organization_aspiration_path(organization, aspiration) }
      end.to change { aspiration.goal_associations.count }.by(1)
    end
  end
end
