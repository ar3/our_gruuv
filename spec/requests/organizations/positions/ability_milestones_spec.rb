# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Position Direct Milestone Requirements', type: :request do
  let(:company) { create(:organization) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:company_teammate, person: person, organization: company, can_manage_maap: true) }
  let(:title) { create(:title, company: company) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let!(:ability1) { create(:ability, company: company) }

  before do
    sign_in_as_teammate_for_request(person, company)
  end

  describe 'GET /organizations/:organization_id/positions/:position_id/ability_milestones' do
    it 'returns success and renders the show page' do
      get organization_position_ability_milestones_path(company, position)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Direct Milestone Requirements')
      expect(response.body).to include(position.display_name)
      expect(response.body).to include('Change Milestone Requirement')
      expect(response.body).to include('Add additional Milestone Requirements')
      expect(response.body).to include('positionAbilityMilestonesPageHelp')
      expect(response.body).to include('Goal of this page')
      expect(response.body).to include('What is MAAP?')
    end

    it 'expands the add section when there are no associations yet' do
      get organization_position_ability_milestones_path(company, position)

      expect(response.body).to include('id="addMilestoneRequirements"')
      expect(response.body).to include('collapse show')
      expect(response.body).to include('No milestone requirements yet')
    end

    it 'shows assignment-required abilities in Change with locked levels and keeps Add collapsed' do
      assignment = create(:assignment, company: company, title: 'Lead Delivery')
      create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required')
      create(:assignment_ability, assignment: assignment, ability: ability1, milestone_level: 3)

      get organization_position_ability_milestones_path(company, position)

      expect(response.body).to include(ability1.name)
      expect(response.body).to include('Milestone 3 is required by Lead Delivery')
      expect(response.body).to include('Milestone 1 is required by Lead Delivery')
      expect(response.body).to match(/id="ability_#{ability1.id}_milestone_1"[^>]*disabled|disabled[^>]*id="ability_#{ability1.id}_milestone_1"/)
      expect(response.body).to match(/id="ability_#{ability1.id}_milestone_3"[^>]*disabled|disabled[^>]*id="ability_#{ability1.id}_milestone_3"/)
      expect(response.body).to include('pointer-events: auto')
      expect(response.body).not_to match(/id="ability_#{ability1.id}_milestone_4"[^>]*disabled|disabled[^>]*id="ability_#{ability1.id}_milestone_4"/)
      expect(response.body).to include('requires more of the')
      expect(response.body).not_to include('class="collapse show" id="addMilestoneRequirements"')
      expect(response.body).not_to include('No milestone requirements yet')
    end

    it 'shows a collapsed expand link when associations exist' do
      create(:position_ability, position: position, ability: ability1, milestone_level: 2)

      get organization_position_ability_milestones_path(company, position)

      expect(response.body).to include('requires more of the')
      expect(response.body).to include('available Abilities')
      expect(response.body).to include(ability1.name)
      expect(response.body).to include('id="addMilestoneRequirements"')
      expect(response.body).to include('aria-controls="addMilestoneRequirements"')
      expect(response.body).not_to include('class="collapse show" id="addMilestoneRequirements"')
      expect(response.body).not_to include('id="addMilestoneRequirements" class="collapse show"')
    end

    it 'shows the view switcher with Direct Milestone Requirements as active when on this page' do
      get organization_position_ability_milestones_path(company, position)

      expect(response.body).to include('Direct Milestone Requirements (Active)')
    end
  end

  describe 'PATCH /organizations/:organization_id/positions/:position_id/ability_milestones' do
    it 'updates position ability milestones and redirects to position show' do
      patch organization_position_ability_milestones_path(company, position), params: {
        position_ability_milestones_form: {
          ability_milestones: { ability1.id.to_s => '3' }
        }
      }

      expect(response).to redirect_to(organization_position_path(company, position))
      expect(flash[:notice]).to be_present
      expect(position.position_abilities.find_by(ability: ability1).milestone_level).to eq(3)
    end
  end
end
