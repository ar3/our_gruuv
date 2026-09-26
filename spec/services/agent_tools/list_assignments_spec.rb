# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentTools::ListAssignments, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:context) do
    AgentTools::Context.new(
      organization: organization,
      person: person,
      company_teammate: teammate
    )
  end

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  it "returns expensive fields by default and excludes archived" do
    live = create(
      :assignment,
      company: organization,
      title: "Ops Lead",
      tagline: "Keep the ops humming",
      required_activities: "Standups daily",
      handbook: "Be kind"
    )
    create(:assignment_outcome, assignment: live, description: "Ship on time")
    archived = create(:assignment, company: organization, title: "Gone")
    archived.archive!

    result = described_class.call(context: context, limit: 50)

    expect(result.ok?).to be(true)
    expect(result.data[:detail]).to eq("expensive")
    titles = result.data[:assignments].map { |a| a[:title] }
    expect(titles).to include("Ops Lead")
    expect(titles).not_to include("Gone")

    row = result.data[:assignments].find { |a| a[:title] == "Ops Lead" }
    expect(row).to include(
      tagline: "Keep the ops humming",
      required_activities: "Standups daily",
      handbook: "Be kind",
      outcomes: ["Ship on time"]
    )
    expect(row[:path]).to be_present
  end

  it "supports minimal detail and query filter" do
    create(:assignment, company: organization, title: "Alpha Role", handbook: "secret")
    create(:assignment, company: organization, title: "Beta Role")

    result = described_class.call(context: context, query: "Alpha", detail: "minimal", limit: 50)

    expect(result.ok?).to be(true)
    expect(result.data[:assignments].size).to eq(1)
    expect(result.data[:assignments].first.keys).to contain_exactly(:title, :path)
    expect(result.data[:detail_hint]).to include("detail=minimal")
  end

  it "paginates with offset and reports has_more / next_offset" do
    3.times { |i| create(:assignment, company: organization, title: "Role #{i}") }

    first = described_class.call(context: context, limit: 2, offset: 0, detail: "minimal")
    expect(first.ok?).to be(true)
    expect(first.data[:count]).to eq(2)
    expect(first.data[:total_count]).to eq(3)
    expect(first.data[:has_more]).to be(true)
    expect(first.data[:next_offset]).to eq(2)
    expect(first.data[:offset]).to eq(0)

    second = described_class.call(context: context, limit: 2, offset: first.data[:next_offset], detail: "minimal")
    expect(second.data[:count]).to eq(1)
    expect(second.data[:has_more]).to be(false)
    expect(second.data[:next_offset]).to be_nil
    expect(second.data[:assignments].map { |a| a[:title] }).not_to include(
      *first.data[:assignments].map { |a| a[:title] }
    )
  end

  it "filters by ability_path and includes ability_milestone_level" do
    ability = create(:ability, company: organization, name: "Software Investigation")
    hit = create(:assignment, company: organization, title: "Needs Investigation")
    miss = create(:assignment, company: organization, title: "Unrelated")
    create(:assignment_ability, assignment: hit, ability: ability, milestone_level: 2)

    ability_path = AgentTools::RecordPaths.ability_path(context, ability)
    result = described_class.call(context: context, ability_path: ability_path, detail: "minimal", limit: 50)

    expect(result.ok?).to be(true)
    titles = result.data[:assignments].map { |a| a[:title] }
    expect(titles).to include("Needs Investigation")
    expect(titles).not_to include("Unrelated")
    expect(result.data[:assignments].first).to include(ability_milestone_level: 2)
    expect(miss).to be_persisted
  end
end
