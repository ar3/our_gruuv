# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamAssignmentCoverer, type: :model do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, company: organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:need) { create(:team_assignment_need, team: team, assignment: assignment) }
  let(:coverer) { create(:company_teammate, organization: organization) }

  it "is valid when the coverer belongs to the team company" do
    record = build(:team_assignment_coverer, team_assignment_need: need, company_teammate: coverer)
    expect(record).to be_valid
  end

  it "requires a unique coverer per need" do
    create(:team_assignment_coverer, team_assignment_need: need, company_teammate: coverer)
    duplicate = build(:team_assignment_coverer, team_assignment_need: need, company_teammate: coverer)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:company_teammate_id]).to be_present
  end

  it "rejects coverers from another company" do
    outsider = create(:company_teammate)
    record = build(:team_assignment_coverer, team_assignment_need: need, company_teammate: outsider)

    expect(record).not_to be_valid
    expect(record.errors[:company_teammate]).to include("must belong to the same company as the team")
  end
end
