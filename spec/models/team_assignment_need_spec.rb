# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamAssignmentNeed, type: :model do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, company: organization) }
  let(:assignment) { create(:assignment, company: organization) }

  it "is valid with required attributes" do
    need = build(:team_assignment_need, team: team, assignment: assignment, need_type: "required")
    expect(need).to be_valid
  end

  it "requires a unique assignment per team" do
    create(:team_assignment_need, team: team, assignment: assignment)
    duplicate = build(:team_assignment_need, team: team, assignment: assignment, need_type: "nice_to_have")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:assignment_id]).to be_present
  end

  it "rejects assignments from another company" do
    other_assignment = create(:assignment)
    need = build(:team_assignment_need, team: team, assignment: other_assignment)

    expect(need).not_to be_valid
    expect(need.errors[:assignment]).to include("must belong to the same company as the team")
  end
end
