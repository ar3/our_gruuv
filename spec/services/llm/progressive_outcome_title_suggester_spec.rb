# frozen_string_literal: true

require "rails_helper"

RSpec.describe Llm::ProgressiveOutcomeTitleSuggester do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:teammate, organization: organization) }
  let(:goal) do
    create(
      :goal,
      creator: teammate,
      owner: teammate,
      company: organization,
      goal_type: "quantitative_key_result",
      title: "Grow paid seats from 120 to about 200 this year",
      started_at: nil
    )
  end

  def stub_client_content(json)
    result = instance_double(Llm::Client::Result, content: json)
    allow(Llm::Client).to receive(:call).and_return(result)
  end

  it "marks high-confidence progressive titles as applyable" do
    stub_client_content({
      is_progressive_outcome: true,
      confidence: 0.93,
      baseline: 120,
      commit: 200,
      stretch: 250,
      transform: nil,
      unit: "seats",
      current_aim: "commit",
      rationale: "baseline to commit"
    }.to_json)

    suggestion = described_class.call(goal: goal)
    expect(suggestion.apply?).to be(true)
    expect(suggestion.commit).to eq(200)
    expect(suggestion.unit).to eq("seats")
  end

  it "does not apply below the confidence threshold" do
    stub_client_content({
      is_progressive_outcome: true,
      confidence: 0.5,
      baseline: 120,
      commit: 200,
      stretch: nil,
      transform: nil,
      unit: "seats",
      current_aim: "commit",
      rationale: "maybe"
    }.to_json)

    expect(described_class.call(goal: goal).apply?).to be(false)
  end
end
