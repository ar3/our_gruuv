# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Assignment Ability Milestones', type: :request do
  let(:company) { create(:organization) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:company_teammate, person: person, organization: company, can_manage_maap: true) }
  let!(:assignment) { create(:assignment, company: company) }
  let!(:ability1) { create(:ability, company: company, name: 'Existing Ability') }
  let!(:ability2) { create(:ability, company: company, name: 'Available Ability') }

  before do
    sign_in_as_teammate_for_request(person, company)
  end

  describe 'GET /organizations/:organization_id/assignments/:assignment_id/ability_milestones' do
    it 'renders two sections and expands add when empty' do
      get organization_assignment_ability_milestones_path(company, assignment)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Change Milestone Requirement')
      expect(response.body).to include('Add additional Milestone Requirements')
      expect(response.body).to include('No milestone requirements yet')
      expect(response.body).to include('collapse show')
      expect(response.body).to include('data-controller="options-filter"')
      expect(response.body).to include('data-bs-toggle="popover"')
      expect(response.body).to include("ability_#{ability1.id}_no_association")
    end

    it 'shows associated abilities in the change section and a collapsed expand link' do
      create(:assignment_ability, assignment: assignment, ability: ability1, milestone_level: 2)

      get organization_assignment_ability_milestones_path(company, assignment)

      expect(response.body).to include(ability1.name)
      expect(response.body).to include("Being a #{assignment.title} requires more of the")
      expect(response.body).to include('available Abilities')
      expect(response.body).to include(ability2.name)
      expect(response.body).to include('No Association')
    end
  end
end
