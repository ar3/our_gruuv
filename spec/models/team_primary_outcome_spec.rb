# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamPrimaryOutcome, type: :model do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, company: organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let!(:need) { create(:team_assignment_need, team: team, assignment: assignment) }
  let(:outcome) { create(:assignment_outcome, assignment: assignment) }

  it "is valid when the outcome belongs to a needed assignment" do
    record = build(:team_primary_outcome, team: team, assignment_outcome: outcome)
    expect(record).to be_valid
  end

  it "requires a unique outcome per team" do
    create(:team_primary_outcome, team: team, assignment_outcome: outcome)
    duplicate = build(:team_primary_outcome, team: team, assignment_outcome: outcome)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:assignment_outcome_id]).to be_present
  end

  it "rejects outcomes whose assignment is not needed by the team" do
    other_assignment = create(:assignment, company: organization)
    other_outcome = create(:assignment_outcome, assignment: other_assignment)
    record = build(:team_primary_outcome, team: team, assignment_outcome: other_outcome)

    expect(record).not_to be_valid
    expect(record.errors[:assignment_outcome]).to include("must belong to an assignment needed by the team")
  end
end
