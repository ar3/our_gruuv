# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentTools::ListAbilities, type: :service do
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

  it "returns expensive fields including null milestones and excludes archived" do
    live = create(
      :ability,
      company: organization,
      created_by: person,
      updated_by: person,
      name: "Negotiation",
      description: "Reach fair agreements",
      milestone_1_description: "Listens well",
      milestone_2_description: nil
    )
    archived = create(
      :ability,
      company: organization,
      created_by: person,
      updated_by: person,
      name: "Archived skill"
    )
    archived.archive!

    result = described_class.call(context: context, limit: 50)

    expect(result.ok?).to be(true)
    names = result.data[:abilities].map { |a| a[:name] }
    expect(names).to include("Negotiation")
    expect(names).not_to include("Archived skill")

    row = result.data[:abilities].find { |a| a[:name] == "Negotiation" }
    expect(row).to include(
      description: "Reach fair agreements",
      milestone_1_description: "Listens well",
      milestone_2_description: nil,
      milestone_3_description: nil,
      milestone_4_description: nil,
      milestone_5_description: nil
    )
    expect(row[:path]).to be_present
  end

  it "supports minimal detail" do
    create(
      :ability,
      company: organization,
      created_by: person,
      updated_by: person,
      name: "Writing",
      description: "Clear prose"
    )

    result = described_class.call(context: context, detail: "minimal", limit: 50)
    row = result.data[:abilities].find { |a| a[:name] == "Writing" }
    expect(row.keys).to contain_exactly(:name, :path)
  end
end
