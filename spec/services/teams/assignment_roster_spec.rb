# frozen_string_literal: true

require "rails_helper"

RSpec.describe Teams::AssignmentRoster, type: :service do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, company: organization) }
  let(:assignment) { create(:assignment, company: organization, title: "Support Lead") }
  let!(:need) { create(:team_assignment_need, team: team, assignment: assignment) }
  let(:team_member) { create(:company_teammate, organization: organization) }
  let(:outsider) { create(:company_teammate, organization: organization) }

  before do
    create(:team_member, team: team, company_teammate: team_member)
    create(:team_assignment_coverer, team_assignment_need: need, company_teammate: team_member)
    create(:team_assignment_coverer, team_assignment_need: need, company_teammate: outsider)
    create(:assignment_tenure, teammate: team_member, assignment: assignment, started_at: 1.month.ago)
  end

  it "flags missing tenure and non-team-member coverers" do
    row = described_class.new(team).required_rows.first

    team_member_status = row.coverer_statuses.find { |status| status.coverer.company_teammate_id == team_member.id }
    outsider_status = row.coverer_statuses.find { |status| status.coverer.company_teammate_id == outsider.id }

    expect(team_member_status.missing_tenure).to be(false)
    expect(team_member_status.not_team_member).to be(false)
    expect(outsider_status.missing_tenure).to be(true)
    expect(outsider_status.not_team_member).to be(true)
  end

  it "lists team members with active tenures as could-cover candidates" do
    row = described_class.new(team).required_rows.first

    expect(row.could_cover_teammates.map(&:id)).to eq([team_member.id])
  end

  it "excludes non-team-members from could-cover even when they hold the assignment" do
    create(:assignment_tenure, teammate: outsider, assignment: assignment, started_at: 1.month.ago)

    row = described_class.new(team).required_rows.first

    expect(row.could_cover_teammates.map(&:id)).to eq([team_member.id])
  end
end
