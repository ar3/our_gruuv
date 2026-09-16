# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ability Assignment Milestones', type: :request do
  let(:company) { create(:organization) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:company_teammate, person: person, organization: company, can_manage_maap: true) }
  let!(:ability) { create(:ability, company: company, name: 'Delivery') }
  let!(:assignment1) { create(:assignment, company: company, title: 'Existing Assignment') }
  let!(:assignment2) { create(:assignment, company: company, title: 'Available Assignment') }

  before do
    sign_in_as_teammate_for_request(person, company)
  end

  describe 'GET /organizations/:organization_id/abilities/:ability_id/assignment_milestones' do
    it 'renders two sections and expands add when empty' do
      get organization_ability_assignment_milestones_path(company, ability)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Change Milestone Requirement')
      expect(response.body).to include('Add additional Milestone Requirements')
      expect(response.body).to include('No milestone requirements yet')
      expect(response.body).to include('collapse show')
    end

    it 'shows a collapsed Add Assignment Milestones expand control when associations exist' do
      create(:assignment_ability, assignment: assignment1, ability: ability, milestone_level: 2)

      get organization_ability_assignment_milestones_path(company, ability)

      expect(response.body).to include(assignment1.title)
      expect(response.body).to include('Add Assignment Milestones')
      expect(response.body).to include("Click to expand if #{ability.name} is required by more of the")
      expect(response.body).to include('available Assignments')
      expect(response.body).to include('bi-chevron-down')
      expect(response.body).to include(assignment2.title)
      expect(response.body).to include('aria-controls="addAssignmentMilestoneRequirements"')
      expect(response.body).not_to include('class="collapse show" id="addAssignmentMilestoneRequirements"')
      expect(response.body).not_to include('id="addAssignmentMilestoneRequirements" class="collapse show"')
    end
  end
end
