# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ability milestone calibration', type: :request do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
  let(:employee) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:assignment) { create(:assignment, company: organization, title: 'Calibration Assignment') }
  let(:ability) { create(:ability, company: organization, name: 'CalibrationAbility') }
  let(:other_ability) { create(:ability, company: organization, name: 'OtherCalibrationAbility') }

  before do
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: employee_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    manager_teammate.update!(first_employed_at: 1.year.ago)
    employee_teammate.update!(first_employed_at: 1.year.ago)
    employee_teammate.employment_tenures.active.first.update!(manager_teammate: manager_teammate)
    create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 2)
    create(:assignment_ability, assignment: assignment, ability: other_ability, milestone_level: 1)
    create(:assignment_tenure, teammate: employee_teammate, assignment: assignment)
  end

  describe 'entry points' do
    it 'shows calibration entry on grow by abilities for the employee' do
      sign_in_as_teammate_for_request(employee, organization)

      get my_growth_abilities_organization_company_teammate_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('One-time ability milestone calibration')
      expect(response.body).to include('2 of 2 abilities need calibration')
      expect(response.body).to include(ability_milestone_calibration_organization_company_teammate_path(organization, employee_teammate))
    end

    it 'shows calibration entry on complete picture for the manager' do
      sign_in_as_teammate_for_request(manager, organization)

      get complete_picture_organization_company_teammate_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('One-time ability milestone calibration')
    end
  end

  describe 'per-ability rating and award' do
    it 'saves on select, keeps first/last audit, and awards when both have rated' do
      sign_in_as_teammate_for_request(employee, organization)

      get ability_milestone_calibration_organization_company_teammate_path(organization, employee_teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Ability milestone calibration')
      expect(response.body).to include('this.form.requestSubmit()')
      expect(response.body).not_to include('Save rating')
      expect(response.body).to include('(you)')
      expect(response.body).to include('will rate what Milestone has been demonstrated')
      expect(response.body).to include('Select a Milestone (1-5) to save immediately')
      expect(response.body).not_to include('You are')
      expect(response.body).not_to include('Select a level')

      calibration = employee_teammate.reload.ability_milestone_calibration
      item = calibration.items.find_by!(ability: ability)
      other_item = calibration.items.find_by!(ability: other_ability)

      patch ability_milestone_calibration_organization_company_teammate_path(organization, employee_teammate),
            params: { item_id: item.id, rating: '2' }
      expect(item.reload.employee_rating).to eq(2)
      expect(item.employee_first_rating).to eq(2)
      expect(item.employee_first_rated_at).to be_present
      expect(item.employee_rating_changed_at).to be_present
      expect(other_item.reload.employee_rating).to be_nil

      first_at = item.employee_first_rated_at
      patch ability_milestone_calibration_organization_company_teammate_path(organization, employee_teammate),
            params: { item_id: item.id, rating: '4' }
      expect(item.reload.employee_rating).to eq(4)
      expect(item.employee_first_rating).to eq(2)
      expect(item.employee_first_rated_at).to be_within(1.second).of(first_at)
      expect(item.employee_rating_changed_at).to be >= item.employee_first_rated_at

      get ability_milestone_calibration_organization_company_teammate_path(organization, employee_teammate)
      expect(response.body).to include('Your rating saved')
      expect(response.body).to include('Waiting on other participant')
      expect(response.body).to include('First: M2')
      expect(response.body).to include('Last change: M4')
      expect(response.body).not_to include('Employee proposal')

      sign_in_as_teammate_for_request(manager, organization)
      patch ability_milestone_calibration_organization_company_teammate_path(organization, employee_teammate),
            params: { item_id: item.id, rating: '3' }
      follow_redirect!
      expect(response.body).to include('Ready to recognize and certify')
      expect(response.body).to include('Employee proposal')
      expect(response.body).to include('Recognize and certify')
      expect(response.body).to include('hereby certify that')
      expect(response.body).to include('Why are you recognizing this Milestone?')
      expect(response.body).to include('name="certification_note"')
      expect(response.body).to include('Other participant:')
      expect(response.body).to include('First: M2')

      expect do
        post award_ability_milestone_calibration_item_organization_company_teammate_path(organization, employee_teammate, item),
             params: { official_milestone_level: '2', certification_note: 'Baseline from calibration talk' }
      end.to change { employee_teammate.teammate_milestones.where(ability: ability).count }.by(2)

      expect(employee_teammate.teammate_milestones.where(ability: ability, milestone_level: 2).pick(:certification_note))
        .to eq('Baseline from calibration talk')

      get ability_milestone_calibration_organization_company_teammate_path(organization, employee_teammate)
      expect(response.body).to include('Milestones earned')
      expect(response.body).to include('Collapsed by default')
      expect(response.body).to include("calibration-history-#{item.id}")
      expect(response.body).to include('Official: Milestone 2')
      earned = employee_teammate.teammate_milestones.find_by!(ability: ability, milestone_level: 2)
      expect(response.body).to include(organization_teammate_milestone_path(organization, earned))
      expect(response.body).to include('View Milestone 2')
      expect(response.body).to include('Reason')
      expect(response.body).to include('Baseline from calibration talk')
      expect(response.body).to match(/class="collapse"[^>]*id="calibration-history-#{item.id}"|id="calibration-history-#{item.id}"[^>]*class="collapse"/)
      expect(response.body).not_to match(/id="calibration-history-#{item.id}"[^>]*class="[^"]*\bshow\b/)
      expect(response.body).not_to match(/class="[^"]*\bshow\b[^"]*"[^>]*id="calibration-history-#{item.id}"/)
    end

    it 'shows the other participant audit under status pills once they have rated' do
      calibration = AbilityMilestoneCalibrationEnsureService.call(teammate: employee_teammate, organization: organization).value
      item = calibration.items.find_by!(ability: ability)
      item.assign_side_rating!(role: :employee, value: 4)

      sign_in_as_teammate_for_request(manager, organization)
      get ability_milestone_calibration_organization_company_teammate_path(organization, employee_teammate)

      expect(response.body).to include('Other participant has rated')
      expect(response.body).to include('Other participant:')
      expect(response.body).to include('First: M4')
      expect(response.body).not_to include('Employee proposal')
    end
  end

  describe 'bulk award warning' do
    it 'steers managers toward calibration from bulk award help' do
      sign_in_as_teammate_for_request(manager, organization)

      get new_bulk_milestone_award_organization_company_teammate_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Prefer one-time milestone calibration')
    end
  end
end
