# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::ScheduleProgressiveOutcomeDefault, type: :service do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:teammate, organization: organization) }

  def create_draft_kr(title:)
    create(
      :goal,
      creator: teammate,
      owner: teammate,
      company: organization,
      goal_type: "quantitative_key_result",
      title: title,
      started_at: nil
    )
  end

  it "applies deterministic prose immediately without enqueueing the LLM job" do
    goal = create_draft_kr(title: "Move retention from 50% to [60|70|80]%")

    expect do
      described_class.call(goal, title_changed: true)
    end.not_to have_enqueued_job(Goals::DefaultProgressiveOutcomeFromTitleJob)

    goal.reload
    expect(goal.goal_type).to eq("progressive_outcome")
    expect(goal.outcome_commit).to eq(BigDecimal("60"))
    expect(goal.outcome_stretch).to eq(BigDecimal("70"))
    expect(goal.outcome_transform).to eq(BigDecimal("80"))
    expect(goal.progressive_current_aim).to eq("commit")
    expect(goal.og3_default_check_result).to include("status=applied_prose")
    expect(goal.og3_default_check_result).to include("Deterministic title prose matched")
  end

  it "applies bare bracket titles without a baseline" do
    goal = create_draft_kr(title: "Handle [1|2|3] requests coming from the insights queue")

    expect do
      described_class.call(goal, title_changed: true)
    end.not_to have_enqueued_job(Goals::DefaultProgressiveOutcomeFromTitleJob)

    goal.reload
    expect(goal.goal_type).to eq("progressive_outcome")
    expect(goal.outcome_baseline).to be_nil
    expect(goal.outcome_commit).to eq(BigDecimal("1"))
    expect(goal.outcome_stretch).to eq(BigDecimal("2"))
    expect(goal.outcome_transform).to eq(BigDecimal("3"))
    expect(goal.og3_default_check_result).to include("status=applied_prose")
  end

  it "enqueues the LLM job when prose parse finds nothing" do
    goal = create_draft_kr(title: "Grow paid seats from 120 to about 200 this year")

    expect do
      described_class.call(goal, title_changed: true)
    end.to have_enqueued_job(Goals::DefaultProgressiveOutcomeFromTitleJob).with(goal.id, goal.title)

    expect(goal.reload.og3_default_check_result).to include("status=enqueued_llm")
    expect(goal.og3_default_check_result).to include("Deterministic prose found nothing")
  end

  it "records a skip when title did not change" do
    goal = create_draft_kr(title: "Grow paid seats from 120 to about 200 this year")

    expect do
      described_class.call(goal, title_changed: false)
    end.not_to have_enqueued_job(Goals::DefaultProgressiveOutcomeFromTitleJob)

    expect(goal.reload.og3_default_check_result).to include("status=skipped_title_unchanged")
  end

  it "records ineligibility for objectives without converting" do
    goal = create_draft_kr(title: "Move retention from 50% to [60|70|80]%")
    goal.update_columns(goal_type: "inspirational_objective")

    described_class.call(goal, title_changed: true)
    goal.reload
    expect(goal.goal_type).to eq("inspirational_objective")
    expect(goal.outcome_commit).to be_nil
    expect(goal.og3_default_check_result).to include("status=skipped_ineligible")
    expect(goal.og3_default_check_result).to include("inspirational_objective")
  end
end
