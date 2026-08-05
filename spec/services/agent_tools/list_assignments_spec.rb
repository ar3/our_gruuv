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
  end
end
