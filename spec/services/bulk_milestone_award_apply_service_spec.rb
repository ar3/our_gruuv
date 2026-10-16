# frozen_string_literal: true

require "rails_helper"

RSpec.describe BulkMilestoneAwardApplyService do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
  let(:employee) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:ability) { create(:ability, company: organization) }

  before do
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: employee_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 2)
    create(:assignment_tenure, teammate: employee_teammate, assignment: assignment)
  end

  it "removes a milestone whose observable moment has kudos without FK failure" do
    milestone = create(
      :teammate_milestone,
      teammate: employee_teammate,
      ability: ability,
      milestone_level: 2,
      certifying_teammate: manager_teammate,
      published_at: Time.current,
      published_by_teammate: manager_teammate
    )
    moment = create(
      :observable_moment,
      :ability_milestone,
      momentable: milestone,
      company: organization,
      primary_potential_observer: manager_teammate,
      created_by: manager
    )
    kudos = create(
      :celebratory_award_transaction,
      company_teammate: employee_teammate,
      organization: organization,
      observable_moment: moment
    )

    result = described_class.call(
      teammate: employee_teammate,
      organization: organization,
      selections_by_ability_id: { ability.id => 0 },
      certifying_teammate: manager_teammate,
      created_by_person: manager
    )

    expect(result.ok?).to eq(true), -> { result.error.to_s }
    expect(TeammateMilestone.exists?(milestone.id)).to eq(false)
    expect(ObservableMoment.exists?(moment.id)).to eq(false)
    expect(kudos.reload.observable_moment_id).to be_nil
  end
end
