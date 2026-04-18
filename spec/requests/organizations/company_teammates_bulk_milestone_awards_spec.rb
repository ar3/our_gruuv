# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Company teammate bulk milestone awards', type: :request do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
  let(:employee) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }

  let(:assignment) { create(:assignment, company: organization, title: 'Bulk Spec Assignment') }
  let(:ability) { create(:ability, company: organization, name: 'BulkSpecAbility') }

  before do
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: employee_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    manager_teammate.update!(first_employed_at: 1.year.ago)
    employee_teammate.update!(first_employed_at: 1.year.ago)
    employee_teammate.employment_tenures.active.first.update!(manager_teammate: manager_teammate)
    create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 2)
    create(:assignment_tenure, teammate: employee_teammate, assignment: assignment)
    create(:assignment_tenure, teammate: manager_teammate, assignment: assignment)
  end

  describe 'when manager awards a report' do
    before { sign_in_as_teammate_for_request(manager, organization) }

    it 'GET new renders the form and milestone radios' do
      get new_bulk_milestone_award_organization_company_teammate_path(organization, employee_teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Bulk Award Milestones!')
      expect(response.body).to include('This is dangerous')
      expect(response.body).to include('BulkSpecAbility')
      expect(response.body).to include(organization_teammate_ability_path(organization, employee_teammate, ability))
      expect(response.body).to include("name=\"milestones[#{ability.id}]\"")
      expect(response.body).to include('Show the reasons why this ability is needed')
      expect(response.body).to include('M2')
      expect(response.body).to include('Bulk Spec Assignment')
      expect(response.body).to include(organization_teammate_assignment_path(organization, employee_teammate, assignment))
      expect(response.body).to include('data-turbo="false"')
    end

    it 'GET new for own teammate shows disabled review with tooltip (cannot award self)' do
      get new_bulk_milestone_award_organization_company_teammate_path(organization, manager_teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Review changes before making them')
      expect(response.body).to include('disabled="disabled"')
      expect(response.body).to include('You cannot award a milestone to yourself')
    end

    it 'POST review for own teammate redirects (cannot bypass disabled UI)' do
      milestones_payload = { ability.id.to_s => '2' }
      post review_bulk_milestone_awards_organization_company_teammate_path(organization, manager_teammate),
           params: { milestones: milestones_payload }
      expect(response).to redirect_to(celebrate_milestones_organization_path(organization))
      follow_redirect!
      expect(response.body).to include('You cannot award a milestone to yourself')
    end

    it 'POST review renders the review step (wizard page 2)' do
      milestones_payload = { ability.id.to_s => '2' }

      post review_bulk_milestone_awards_organization_company_teammate_path(organization, employee_teammate),
           params: { milestones: milestones_payload }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Bulk Award Milestones - Review')
      expect(response.body).to include('Certification')
      expect(response.body).to include('Milestones being removed')
      expect(response.body).to include('Save bulk milestone adjustment')
    end

    it 'POST review without milestone params redirects back to new with an alert' do
      post review_bulk_milestone_awards_organization_company_teammate_path(organization, employee_teammate),
           params: {}

      expect(response).to redirect_to(new_bulk_milestone_award_organization_company_teammate_path(organization, employee_teammate))
      follow_redirect!
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Each ability must have a milestone level selected')
    end

    it 'POST review then POST create adds prerequisite milestones with correct visibility' do
      milestones_payload = { ability.id.to_s => '2' }

      post review_bulk_milestone_awards_organization_company_teammate_path(organization, employee_teammate),
           params: { milestones: milestones_payload }
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Certification')
      expect(response.body).to include('Milestones being removed')

      expect do
        post bulk_milestone_awards_organization_company_teammate_path(organization, employee_teammate),
             params: { milestones: milestones_payload }
      end.to change { employee_teammate.teammate_milestones.where(ability: ability).count }.from(0).to(2)

      expect(response).to redirect_to(new_bulk_milestone_award_organization_company_teammate_path(organization, employee_teammate))

      m1 = employee_teammate.teammate_milestones.find_by!(ability: ability, milestone_level: 1)
      m2 = employee_teammate.teammate_milestones.find_by!(ability: ability, milestone_level: 2)
      expect(m1.published_at).to be_nil
      expect(m2.published_at).to be_present
      expect(m1.certification_note).to eq(BulkMilestoneAwardApplyService::CERTIFICATION_NOTE)
      expect(m2.certification_note).to eq(BulkMilestoneAwardApplyService::CERTIFICATION_NOTE)
    end
  end

  describe 'when viewer is not eligible to award the teammate' do
    let(:peer) { create(:person) }
    let(:peer_teammate) { create(:teammate, person: peer, organization: organization) }

    before do
      create(:employment_tenure, teammate: peer_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      peer_teammate.update!(first_employed_at: 1.year.ago)
      sign_in_as_teammate_for_request(peer, organization)
    end

    it 'GET new redirects away' do
      get new_bulk_milestone_award_organization_company_teammate_path(organization, employee_teammate)
      expect(response).to redirect_to(celebrate_milestones_organization_path(organization))
    end
  end
end
