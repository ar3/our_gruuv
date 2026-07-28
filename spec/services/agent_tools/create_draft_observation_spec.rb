# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentTools::CreateDraftObservation, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:observee_person) { create(:person) }
  let(:observee) { create(:teammate, person: observee_person, organization: organization) }
  let(:context) do
    AgentTools::Context.new(
      organization: organization,
      person: person,
      company_teammate: teammate
    )
  end
  let(:observee_path) { AgentTools::RecordPaths.teammate_path(context, observee) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: observee, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  it "creates a draft observation with published_at nil" do
    result = described_class.call(
      context: context,
      observee_path: observee_path,
      story: "Great collaboration on the launch",
      observation_type: "kudos"
    )

    expect(result.ok?).to be(true), -> { result.error.inspect }
    observation = Observation.order(:id).last
    expect(observation.published_at).to be_nil
    expect(observation).to be_draft
    expect(observation.story).to eq("Great collaboration on the launch")
    expect(observation.observation_type).to eq("kudos")
    expect(observation.created_as_type).to eq("ask_og")
    expect(observation.observees.pluck(:teammate_id)).to eq([observee.id])
    expect(result.data[:redirect_path]).to include("/observations/")
    expect(result.data[:path]).to be_present
  end

  it "accepts mcp trigger_source for MCP adapter provenance" do
    result = described_class.call(
      context: context,
      observee_path: observee_path,
      story: "MCP draft",
      trigger_source: "mcp"
    )

    expect(result.ok?).to be(true), -> { result.error.inspect }
    observation = Observation.order(:id).last
    expect(observation.created_as_type).to eq("mcp")
    expect(observation.observation_trigger.trigger_source).to eq("mcp")
  end

  it "does not publish" do
    result = described_class.call(
      context: context,
      observee_path: observee_path,
      story: "Note"
    )
    expect(result.ok?).to be(true)
    expect(Observation.order(:id).last.published?).to be(false)
  end
end
