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
      expect(response.body).to include('2 of 2 Abilities need calibration')
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
      expect(response.body).to include('Select a Milestone (0-5) to save immediately')
      expect(response.body).to include("id=\"calibration_rating_")
      expect(response.body).to include('value="0"')
      expect(response.body).not_to include('You are')
      expect(response.body).not_to include('Select a level')
      expect(response.body).to include('Expand for Ability details')
      expect(response.body).to include('Why is this Ability here?')
      expect(response.body).to include("#{employee.casual_name} is actively taking on")
      expect(response.body).to include(assignment.title)
      expect(response.body).to include(organization_teammate_assignment_path(organization, employee_teammate, assignment))
      expect(response.body).not_to include('Assignment tenure:')
      expect(response.body).to include('Ability description')
      expect(response.body).to include('Milestones')
      expect(response.body).to include('No Milestone earned yet for this Ability.')
      expect(response.body).to include('actively working on earning Milestone 1')
      expect(response.body).to include('Add Goal')
      expect(response.body).to include('Grow By Abilities')
      expect(response.body).to include(my_growth_abilities_organization_company_teammate_path(organization, employee_teammate))
      expect(response.body).to include("Observations on #{ability.display_name} Ability")
      expect(response.body).to include("#{employee.casual_name} + #{ability.display_name} Ability page")
      expect(response.body).to include("All OGOs for #{employee.casual_name} + #{ability.display_name} Ability")
      expect(response.body).to include(organization_teammate_ability_path(organization, employee_teammate, ability))
      expect(response.body).to include('rateable_type=Ability')
      expect(response.body).to include("rateable_id=#{ability.id}")
      expect(response.body).not_to include('bs-toggle="popover"')
      expect(response.body).not_to include("data-bs-toggle=\"popover\"")
      expect(response.body).to match(/id="calibration-ability-details-\d+"[^>]*class="collapse"|class="collapse"[^>]*id="calibration-ability-details-\d+"/)
      expect(response.body).not_to match(/id="calibration-ability-details-\d+"[^>]*class="[^"]*\bshow\b/)

      calibration = employee_teammate.reload.ability_milestone_calibration
      item = calibration.items.find_by!(ability: ability)
      other_item = calibration.items.find_by!(ability: other_ability)
      expect(response.body).to include("id=\"calibration-item-#{item.id}\"")
      expect(response.body).to include("id=\"calibration_rating_#{item.id}_0\"")

      patch ability_milestone_calibration_organization_company_teammate_path(organization, employee_teammate),
            params: { item_id: other_item.id, rating: '0' }
      expect(response).to redirect_to(
        ability_milestone_calibration_organization_company_teammate_path(
          organization, employee_teammate, anchor: "calibration-item-#{other_item.id}"
        )
      )
      expect(other_item.reload.employee_rating).to eq(0)
      expect(other_item.employee_first_rating).to eq(0)
      expect(other_item.employee_rated?).to be(true)

      patch ability_milestone_calibration_organization_company_teammate_path(organization, employee_teammate),
            params: { item_id: item.id, rating: '2' }
      expect(response).to redirect_to(
        ability_milestone_calibration_organization_company_teammate_path(
          organization, employee_teammate, anchor: "calibration-item-#{item.id}"
        )
      )
      expect(item.reload.employee_rating).to eq(2)
      expect(item.employee_first_rating).to eq(2)
      expect(item.employee_first_rated_at).to be_present
      expect(item.employee_rating_changed_at).to be_present
      expect(other_item.reload.employee_rating).to eq(0)

      first_at = item.employee_first_rated_at
      patch ability_milestone_calibration_organization_company_teammate_path(organization, employee_teammate),
            params: { item_id: item.id, rating: '4' }
      expect(response).to redirect_to(
        ability_milestone_calibration_organization_company_teammate_path(
          organization, employee_teammate, anchor: "calibration-item-#{item.id}"
        )
      )
      expect(item.reload.employee_rating).to eq(4)
      expect(item.employee_first_rating).to eq(2)
      expect(item.employee_first_rated_at).to be_within(1.second).of(first_at)
      expect(item.employee_rating_changed_at).to be >= item.employee_first_rated_at

      get ability_milestone_calibration_organization_company_teammate_path(organization, employee_teammate)
      expect(response.body).to include('Your rating saved')
      expect(response.body).to include("Waiting on #{manager.casual_name}")
      expect(response.body).to include('First: M2')
      expect(response.body).to include('Last change: M4')
      expect(response.body).not_to include('Employee proposal')
      expect(response.body).not_to include("#{manager.casual_name}:")

      sign_in_as_teammate_for_request(manager, organization)
      patch ability_milestone_calibration_organization_company_teammate_path(organization, employee_teammate),
            params: { item_id: item.id, rating: '3' }
      expect(response).to redirect_to(
        ability_milestone_calibration_organization_company_teammate_path(
          organization, employee_teammate, anchor: "calibration-item-#{item.id}"
        )
      )
      follow_redirect!
      expect(response.body).to include('Ready to submit certification')
      expect(response.body).to include('Employee proposal')
      expect(response.body).to include('Submit certification')
      expect(response.body).to include('hereby certify that')
      expect(response.body).to include('Why are you recognizing this Milestone?')
      expect(response.body).to include('name="certification_note"')
      expect(response.body).to include('Evidence: co-sign')
      expect(response.body).to include('name="awarder_typed_name"')
      expect(response.body).to include('Skip co-sign')
      expect(response.body).to include("#{employee.casual_name}:")
      expect(response.body).to include('First: M2')
      expect(response.body).to include('Click here to change your milestone selection...')
      expect(response.body).to include('or make the final Milestone certification above')
      expect(response.body).to include("id=\"calibration-manager-rating-#{item.id}\"")
      expect(response.body).not_to match(/id="calibration-manager-rating-#{item.id}"[^>]*class="[^"]*\bshow\b/)
      expect(response.body).not_to match(/class="[^"]*\bshow\b[^"]*"[^>]*id="calibration-manager-rating-#{item.id}"/)

      expect do
        post award_ability_milestone_calibration_item_organization_company_teammate_path(organization, employee_teammate, item),
             params: {
               official_milestone_level: '2',
               certification_note: 'Baseline from calibration talk',
               awarder_typed_name: manager.all_names_display_name,
               skip_cosign: '1'
             }
      end.to change { employee_teammate.teammate_milestones.where(ability: ability).count }.by(2)

      expect(response).to redirect_to(
        ability_milestone_calibration_organization_company_teammate_path(
          organization, employee_teammate, anchor: "calibration-history-#{item.id}"
        )
      )

      expect(employee_teammate.teammate_milestones.where(ability: ability, milestone_level: 2).pick(:certification_note))
        .to eq('Baseline from calibration talk')

      get ability_milestone_calibration_organization_company_teammate_path(organization, employee_teammate)
      expect(response.body).to include('Milestones earned')
      expect(response.body).to include('Collapsed by default')
      expect(response.body).to include("calibration-history-#{item.id}")
      expect(response.body).to include('Official: Milestone 2')
      expect(response.body).to include('Skipped co-sign')
      expect(response.body).not_to include('Awaiting co-signer')
      earned = employee_teammate.teammate_milestones.find_by!(ability: ability, milestone_level: 2)
      expect(response.body).to include(organization_teammate_milestone_path(organization, earned))
      expect(response.body).to include('View Milestone 2')
      expect(response.body).to include('Reason')
      expect(response.body).to include('Baseline from calibration talk')
      expect(response.body).to match(/class="collapse"[^>]*id="calibration-history-#{item.id}"|id="calibration-history-#{item.id}"[^>]*class="collapse"/)
      expect(response.body).not_to match(/id="calibration-history-#{item.id}"[^>]*class="[^"]*\bshow\b/)
      expect(response.body).not_to match(/class="[^"]*\bshow\b[^"]*"[^>]*id="calibration-history-#{item.id}"/)
    end

    it 'lists abilities awaiting co-sign in their own section until co-signed' do
      calibration = AbilityMilestoneCalibrationEnsureService.call(teammate: employee_teammate, organization: organization).value
      item = calibration.items.find_by!(ability: ability)
      item.assign_side_rating!(role: :employee, value: 2)
      item.assign_side_rating!(role: :manager, value: 2)
      cosigner = create(:teammate, :assigned_employee, organization: organization)
      create(:employment_tenure, teammate: cosigner, company: organization, started_at: 1.year.ago, ended_at: nil)

      sign_in_as_teammate_for_request(manager, organization)
      post award_ability_milestone_calibration_item_organization_company_teammate_path(organization, employee_teammate, item),
           params: {
             official_milestone_level: '2',
             certification_note: 'Needs a co-signer',
             awarder_typed_name: manager.all_names_display_name,
             cosign_invitee_ids: [cosigner.id]
           }

      award = MilestoneAward.find_by!(ability_milestone_calibration_item_id: item.id)
      expect(award.pending_cosign?).to eq(true)

      get ability_milestone_calibration_organization_company_teammate_path(organization, employee_teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Awaiting co-signer')
      expect(response.body).to include("calibration-awaiting-#{item.id}")
      expect(response.body).to include('View award / co-sign status')
      expect(response.body).to include(
        organization_teammate_ability_milestone_award_path(organization, employee_teammate, ability, award)
      )
      expect(response.body).not_to include("calibration-history-#{item.id}")

      MilestoneAwards::CosignService.call(
        milestone_award: award,
        cosigning_teammate: cosigner,
        typed_name: cosigner.person.all_names_display_name,
        reason: 'Looks good'
      )

      get ability_milestone_calibration_organization_company_teammate_path(organization, employee_teammate)
      expect(response.body).not_to include('Awaiting co-signer')
      expect(response.body).to include('Milestones earned')
      expect(response.body).to include("calibration-history-#{item.id}")
      expect(response.body).to include('Co-signed by')
      expect(response.body).to include(cosigner.person.display_name)
    end

    it 'shows catalog Abilities with prior milestones as calibration-skipped in Milestones earned' do
      prior = create(
        :teammate_milestone,
        teammate: employee_teammate,
        ability: other_ability,
        milestone_level: 1,
        certifying_teammate: manager_teammate,
        attained_at: 2.months.ago,
        certification_note: 'Awarded before calibration'
      )

      sign_in_as_teammate_for_request(manager, organization)
      get ability_milestone_calibration_organization_company_teammate_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('1 of 2 Abilities need calibration')
      expect(response.body).to include('already have a Milestone and appear under Milestones earned')
      expect(response.body).to include('Milestones earned')
      expect(response.body).to include('Calibration skipped')
      expect(response.body).to include(other_ability.display_name)
      expect(response.body).to include("calibration-skipped-ability-#{other_ability.id}")
      expect(response.body).to include('without going through one-time calibration')
      expect(response.body).to include(organization_teammate_milestone_path(organization, prior))
      expect(response.body).to include(ability.display_name)
      expect(response.body).not_to include("calibration-skipped-ability-#{ability.id}")
    end

    it 'keeps submitted award form values after a validation error' do
      calibration = AbilityMilestoneCalibrationEnsureService.call(teammate: employee_teammate, organization: organization).value
      item = calibration.items.find_by!(ability: ability)
      item.assign_side_rating!(role: :employee, value: 2)
      item.assign_side_rating!(role: :manager, value: 3)
      cosigner = create(:teammate, :assigned_employee, organization: organization)
      create(:employment_tenure, teammate: cosigner, company: organization, started_at: 1.year.ago, ended_at: nil)

      sign_in_as_teammate_for_request(manager, organization)
      post award_ability_milestone_calibration_item_organization_company_teammate_path(organization, employee_teammate, item),
           params: {
             official_milestone_level: '3',
             certification_note: 'Keep this note',
             awarder_typed_name: 'Wrong Name',
             cosign_invitee_ids: [cosigner.id]
           }

      expect(response).to redirect_to(
        ability_milestone_calibration_organization_company_teammate_path(
          organization, employee_teammate, anchor: "calibration-item-#{item.id}"
        )
      )
      follow_redirect!

      expect(response.body).to include('must match your full name').or include('full name')
      expect(response.body).to include('value="Wrong Name"')
      expect(response.body).to include('Keep this note')
      expect(response.body).to match(/name="official_milestone_level"[^>]*value="3"[^>]*checked|value="3"[^>]*name="official_milestone_level"[^>]*checked/)
      expect(response.body).to match(/value="#{cosigner.id}"[^>]*selected|selected[^>]*value="#{cosigner.id}"/)
    end

    it 'shows only a pill when the other side has rated until you complete your side' do
      calibration = AbilityMilestoneCalibrationEnsureService.call(teammate: employee_teammate, organization: organization).value
      item = calibration.items.find_by!(ability: ability)
      item.assign_side_rating!(role: :employee, value: 4)

      sign_in_as_teammate_for_request(manager, organization)
      get ability_milestone_calibration_organization_company_teammate_path(organization, employee_teammate)

      expect(response.body).to include("#{employee.casual_name} has rated")
      expect(response.body).to include('Your rating still needed')
      expect(response.body).not_to include("<span class=\"fw-semibold\">#{employee.casual_name}:</span>")
      expect(response.body).not_to include('First: M4')
      expect(response.body).not_to include('Employee proposal')
    end
  end

  describe 'ability details accordion OGOs' do
    def create_ability_observation!(story:, observed_at:)
      obs = build(
        :observation,
        observer: manager,
        company: organization,
        privacy_level: :observed_and_managers,
        published_at: observed_at,
        observed_at: observed_at,
        story: story
      )
      obs.observees = []
      obs.observees.build(teammate: employee_teammate)
      obs.save!
      create(:observation_rating, observation: obs, rateable: ability, rating: :agree)
      obs
    end

    it 'lists recent OGOs with large-list rows and a 5 of X caption when more than five exist' do
      6.times do |i|
        create_ability_observation!(
          story: "Calibration OGO story number #{i}",
          observed_at: (6 - i).days.ago
        )
      end

      sign_in_as_teammate_for_request(employee, organization)
      get ability_milestone_calibration_organization_company_teammate_path(organization, employee_teammate)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('showing 5 of 6')
      expect(response.body).to include('Calibration OGO story number 5')
      expect(response.body).to include('Calibration OGO story number 1')
      expect(response.body).not_to include('Calibration OGO story number 0')
      expect(response.body).to include('From:')
      expect(response.body).to include(manager.casual_name)
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
