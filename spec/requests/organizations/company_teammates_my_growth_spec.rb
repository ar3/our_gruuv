require 'rails_helper'

RSpec.describe 'Company teammate My Growth', type: :request do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
  let(:employee) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:peer) { create(:person) }
  let(:peer_teammate) { create(:teammate, person: peer, organization: organization) }

  before do
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: employee_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: peer_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    manager_teammate.update!(first_employed_at: 1.year.ago)
    employee_teammate.update!(first_employed_at: 1.year.ago)
    peer_teammate.update!(first_employed_at: 1.year.ago)
  end

  describe 'authorization' do
    context 'when manager views direct report' do
      before do
        employee_teammate.employment_tenures.active.first&.update!(manager_teammate: manager_teammate)
        sign_in_as_teammate_for_request(manager, organization)
      end

      it 'allows GET my_growth/experiences' do
        get my_growth_experiences_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to have_http_status(:success)
      end

      it 'allows GET my_growth/abilities' do
        get my_growth_abilities_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to have_http_status(:success)
      end

      it 'allows GET my_growth/goals' do
        get my_growth_goals_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to have_http_status(:success)
        expect(response.body).to include("View and check-in on all of #{employee.casual_name}'s goals")
      end

      it 'allows GET my_growth/position_change' do
        get my_growth_position_change_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when peer (no hierarchy) views another employee' do
      before { sign_in_as_teammate_for_request(peer, organization) }

      it 'denies my_growth/experiences' do
        get my_growth_experiences_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end

    context 'when unauthenticated' do
      it 'redirects to login' do
        get my_growth_experiences_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'PATCH update_next_goal_position' do
    let(:title) { create(:title, company: organization) }
    let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
    let(:position) { create(:position, title: title, position_level: position_level) }

    before do
      employee_teammate.employment_tenures.active.first&.update!(manager_teammate: manager_teammate)
      sign_in_as_teammate_for_request(manager, organization)
    end

    it 'updates next_goal_position_id' do
      patch update_next_goal_position_organization_company_teammate_path(organization, employee_teammate),
            params: { next_goal_position_id: position.id }
      expect(response).to redirect_to(my_growth_position_change_organization_company_teammate_path(organization, employee_teammate))
      expect(employee_teammate.reload.next_goal_position_id).to eq(position.id)
    end

    it 'clears next_goal_position_id when blank' do
      employee_teammate.update!(next_goal_position: position)
      patch update_next_goal_position_organization_company_teammate_path(organization, employee_teammate),
            params: { next_goal_position_id: '' }
      expect(employee_teammate.reload.next_goal_position_id).to be_nil
    end

    context 'when position is for another company' do
      let(:other_title) { create(:title, company: other_organization) }
      let(:other_level) { create(:position_level, position_major_level: other_title.position_major_level) }
      let(:other_position) { create(:position, title: other_title, position_level: other_level) }

      it 'rejects the update' do
        patch update_next_goal_position_organization_company_teammate_path(organization, employee_teammate),
              params: { next_goal_position_id: other_position.id }
        expect(employee_teammate.reload.next_goal_position_id).to be_nil
        expect(flash[:alert]).to be_present
      end
    end
  end
end
