# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observations::OgoQualityRunner do
  let(:organization) { create(:organization, :company) }
  let(:observation) { create(:observation, company: organization) }
  let(:consultation) { create_ogo_quality_consultation!(observation: observation) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:llm_json) do
    {
      quality: {
        observation: { score: 80, notes: "Camera-test action." },
        emotion: { score: 70, notes: "Named a real feeling." },
        impact: { score: 60, notes: "Clear outcome for the team." },
        summary: "Name the feeling more specifically.",
        improvements: ["Add what a camera would have seen."],
        ogo_worthy: true
      },
      proposed_objects: [
        {
          rateable_type: "Assignment",
          rateable_id: assignment.id,
          rating: "agree",
          reason: "They owned the launch outcome."
        },
        {
          rateable_type: "Assignment",
          rateable_id: 9_999_999,
          rating: "strongly_agree",
          reason: "Invented id"
        }
      ]
    }.to_json
  end

  before do
    create(:assignment_tenure, teammate: observation.observed_teammates.first, assignment: assignment, anticipated_energy_percentage: 50)
    allow_any_instance_of(described_class).to receive(:bedrock_configured?).and_return(true)
    allow(Llm::Client).to receive(:call).and_return(instance_double(Llm::Client::Result, content: llm_json))
  end

  it "stores sanitized quality and catalog-safe proposed objects" do
    described_class.call(observation: observation, og_consultation: consultation)

    consultation.reload
    expect(consultation.status).to eq("completed")
    result = consultation.result
    expect(result.quality["summary"]).to eq("Name the feeling more specifically.")
    expect(result.quality["improvements"]).to eq(["Add what a camera would have seen."])
    expect(result.quality["observation"]["score"]).to eq(80)
    expect(result.proposed_objects.size).to eq(1)
    expect(result.proposed_objects.first["rateable_id"]).to eq(assignment.id)
    expect(result.proposed_objects.first["rating"]).to eq("agree")
  end

  it "marks OGO-worthy when emotion is above 70 even with no objects" do
    json = {
      quality: {
        observation: { score: 40, notes: "Thin on facts." },
        emotion: { score: 71, notes: "This made people proud." },
        impact: { score: 20, notes: "No clear MAAP object." },
        summary: "Not an assignment display.",
        ogo_worthy: false
      },
      proposed_objects: []
    }.to_json
    allow(Llm::Client).to receive(:call).and_return(instance_double(Llm::Client::Result, content: json))

    described_class.call(observation: observation, og_consultation: consultation)

    result = consultation.reload.result
    expect(result.quality["ogo_worthy"]).to be(true)
    expect(result.proposed_objects).to eq([])
  end

  it "keeps ogo_worthy internal and scrubs pass/fail wording from coaching text" do
    json = {
      quality: {
        observation: { score: 20, notes: "Not OGO-worthy camera test." },
        emotion: { score: 40, notes: "Warm." },
        impact: { score: 10, notes: "Thin." },
        summary: "This is not OGO-worthy yet.",
        improvements: ["Make it OGO-worthy by naming the action."],
        ogo_worthy: false
      },
      proposed_objects: []
    }.to_json
    allow(Llm::Client).to receive(:call).and_return(instance_double(Llm::Client::Result, content: json))

    described_class.call(observation: observation, og_consultation: consultation)

    result = consultation.reload.result
    expect(result.quality["ogo_worthy"]).to be(false)
    expect(result.quality["summary"]).not_to match(/ogo[-\s]?worthy/i)
    expect(result.quality["observation"]["notes"]).not_to match(/ogo[-\s]?worthy/i)
    expect(result.quality["improvements"].join).not_to match(/ogo[-\s]?worthy/i)
  end

  it "does not treat emotion of 70 as automatically worthy" do
    json = {
      quality: {
        observation: { score: 20, notes: "Vague." },
        emotion: { score: 70, notes: "Warm but generic." },
        impact: { score: 10, notes: "No impact." },
        summary: "Not OGO-worthy.",
        ogo_worthy: false
      },
      proposed_objects: []
    }.to_json
    allow(Llm::Client).to receive(:call).and_return(instance_double(Llm::Client::Result, content: json))

    described_class.call(observation: observation, og_consultation: consultation)

    expect(consultation.reload.result.quality["ogo_worthy"]).to be(false)
  end
end
