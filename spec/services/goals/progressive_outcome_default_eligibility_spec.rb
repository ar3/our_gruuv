# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::ProgressiveOutcomeDefaultEligibility do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:teammate, organization: organization) }

  def build_goal(**attrs)
    create(
      :goal,
      {
        creator: teammate,
        owner: teammate,
        company: organization,
        goal_type: "quantitative_key_result",
        title: "Move retention from 50% to 70%",
        started_at: nil
      }.merge(attrs)
    )
  end

  it "is eligible for a draft KR with multi-digit title and blank OG3 fields" do
    expect(described_class.eligible?(build_goal)).to be(true)
  end

  it "rejects started goals" do
    expect(described_class.eligible?(build_goal(started_at: 1.day.ago))).to be(false)
  end

  it "rejects inspirational objectives" do
    expect(described_class.eligible?(build_goal(goal_type: "inspirational_objective"))).to be(false)
  end

  it "rejects when any progressive field is set" do
    expect(described_class.eligible?(build_goal(outcome_commit: 60))).to be(false)
  end

  it "rejects titles with fewer than two digit characters" do
    expect(described_class.eligible?(build_goal(title: "Ship feature 1"))).to be(false)
  end

  it "rejects manually locked outcome fields" do
    expect(described_class.eligible?(build_goal(outcome_fields_manually_edited_at: Time.current))).to be(false)
  end
end
