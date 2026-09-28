# frozen_string_literal: true

require "rails_helper"

RSpec.describe MaapProposals::AssignmentDiffBuilder do
  let(:organization) { create(:organization) }
  let(:assignment) do
    create(
      :assignment,
      company: organization,
      title: "Live Title",
      tagline: "Live tagline",
      handbook: "Live handbook"
    )
  end

  it "returns only changed fields with Diffy HTML" do
    payload = MaapProposals::AssignmentPayload.from_hash(
      MaapProposals::AssignmentPayload.from_assignment(assignment).to_h.merge(
        "title" => "Proposed Title",
        "handbook" => "Proposed handbook"
      )
    )

    diffs = described_class.call(assignment: assignment, payload: payload)

    expect(diffs.map(&:key)).to contain_exactly(:title, :handbook)
    expect(diffs.map(&:label)).to contain_exactly("Title", "Handbook")
    title_diff = diffs.find { |d| d.key == :title }
    expect(title_diff.html).to include("diff")
    expect(title_diff.html).to include("Proposed")
    expect(title_diff.after).to eq("Proposed Title")
  end

  it "returns no diffs when payload matches live assignment" do
    payload = MaapProposals::AssignmentPayload.from_assignment(assignment)
    expect(described_class.call(assignment: assignment, payload: payload)).to eq([])
  end
end
