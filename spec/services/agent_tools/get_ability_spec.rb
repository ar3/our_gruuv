# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentTools::GetAbility, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, :assigned_employee, person: person, organization: organization) }
  let(:context) do
    AgentTools::Context.new(
      organization: organization,
      person: person,
      company_teammate: teammate
    )
  end
  let(:ability) do
    create(
      :ability,
      company: organization,
      name: "Software Investigation",
      description: "Find root causes",
      milestone_1_description: "Follow a runbook",
      milestone_3_description: "Lead investigations",
      milestone_5_description: nil
    )
  end

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  it "returns full body including milestone descriptions" do
    path = AgentTools::RecordPaths.ability_path(context, ability)
    result = described_class.call(context: context, path: path)

    expect(result.ok?).to be(true)
    row = result.data[:ability]
    expect(row).to include(
      name: "Software Investigation",
      description: "Find root causes",
      milestone_1_description: "Follow a runbook",
      milestone_3_description: "Lead investigations",
      milestone_5_description: nil
    )
    expect(row[:path]).to be_present
  end

  it "errors when path missing" do
    result = described_class.call(context: context)
    expect(result.ok?).to be(false)
    expect(result.error_code).to eq("validation_failed")
  end
end
