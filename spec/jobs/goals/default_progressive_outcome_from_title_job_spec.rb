# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::DefaultProgressiveOutcomeFromTitleJob, type: :job do
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

  def suggestion(**overrides)
    Llm::ProgressiveOutcomeTitleSuggester::Suggestion.new(
      {
        apply?: true,
        confidence: 0.91,
        baseline: 120,
        commit: 200,
        stretch: 250,
        transform: 400,
        unit: "seats",
        current_aim: "commit",
        rationale: "clear baseline to target"
      }.merge(overrides)
    )
  end

  it "applies a high-confidence LLM suggestion" do
    allow(Llm::ProgressiveOutcomeTitleSuggester).to receive(:call).and_return(suggestion)

    described_class.new.perform(goal.id, goal.title)

    goal.reload
    expect(goal.goal_type).to eq("progressive_outcome")
    expect(goal.outcome_baseline).to eq(BigDecimal("120"))
    expect(goal.outcome_commit).to eq(BigDecimal("200"))
    expect(goal.outcome_stretch).to eq(BigDecimal("250"))
    expect(goal.outcome_unit).to eq("seats")
    expect(goal.progressive_current_aim).to eq("commit")
    expect(goal.og3_default_check_result).to include("status=llm_applied")
  end

  it "skips when the title changed since enqueue" do
    allow(Llm::ProgressiveOutcomeTitleSuggester).to receive(:call)

    described_class.new.perform(goal.id, "old title with 12 and 34")

    expect(Llm::ProgressiveOutcomeTitleSuggester).not_to have_received(:call)
    goal.reload
    expect(goal.goal_type).to eq("quantitative_key_result")
    expect(goal.og3_default_check_result).to include("status=llm_skipped_title_changed")
  end

  it "skips low-confidence suggestions" do
    allow(Llm::ProgressiveOutcomeTitleSuggester).to receive(:call).and_return(
      suggestion(apply?: false, confidence: 0.4)
    )

    described_class.new.perform(goal.id, goal.title)
    goal.reload
    expect(goal.goal_type).to eq("quantitative_key_result")
    expect(goal.og3_default_check_result).to include("status=llm_declined")
    expect(goal.og3_default_check_result).to include("confidence: 0.4")
  end
end
