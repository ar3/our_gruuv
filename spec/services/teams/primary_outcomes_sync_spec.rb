# frozen_string_literal: true

require "rails_helper"

RSpec.describe Teams::PrimaryOutcomesSync do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, company: organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let!(:need) { create(:team_assignment_need, team: team, assignment: assignment) }
  let!(:outcome_a) { create(:assignment_outcome, assignment: assignment, description: "Ship weekly") }
  let!(:outcome_b) { create(:assignment_outcome, assignment: assignment, description: "Keep NPS high") }
  let!(:unneeded_outcome) do
    other = create(:assignment, company: organization)
    create(:assignment_outcome, assignment: other, description: "Not on this team")
  end

  it "creates primary outcomes for eligible selected ids" do
    described_class.new(team: team, assignment_outcome_ids: [outcome_a.id, unneeded_outcome.id]).call

    expect(team.team_primary_outcomes.pluck(:assignment_outcome_id)).to eq([outcome_a.id])
  end

  it "removes previously selected outcomes that are no longer listed" do
    create(:team_primary_outcome, team: team, assignment_outcome: outcome_a)
    create(:team_primary_outcome, team: team, assignment_outcome: outcome_b)

    described_class.new(team: team, assignment_outcome_ids: [outcome_b.id]).call

    expect(team.team_primary_outcomes.pluck(:assignment_outcome_id)).to eq([outcome_b.id])
  end

  it "clears all primary outcomes when none are selected" do
    create(:team_primary_outcome, team: team, assignment_outcome: outcome_a)

    described_class.new(team: team, assignment_outcome_ids: []).call

    expect(team.team_primary_outcomes).to be_empty
  end
end
