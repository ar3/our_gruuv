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
      expect(response.body).to include('this.form.requestSubmit()')
      expect(response.body).not_to include('Save rating')
      expect(response.body).not_to include('Your proposed level')

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
      expect(response.body).to include('Ready for review')
      expect(response.body).to include('Employee proposal')
      expect(response.body).to include('Award this ability')
      expect(response.body).to include('Other participant:')
      expect(response.body).to include('First: M2')

      expect do
        post award_ability_milestone_calibration_item_organization_company_teammate_path(organization, employee_teammate, item),
             params: { official_milestone_level: '2' }
      end.to change { employee_teammate.teammate_milestones.where(ability: ability).count }.by(2)

      get ability_milestone_calibration_organization_company_teammate_path(organization, employee_teammate)
      expect(response.body).to include('Awarded history')
      expect(response.body).to include('collapsed by default')
      expect(response.body).to include("calibration-history-#{item.id}")
      expect(response.body).to include('Official: Milestone 2')
      expect(response.body).to include('collapse')
      expect(response.body).not_to include('class="collapse show"')
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
