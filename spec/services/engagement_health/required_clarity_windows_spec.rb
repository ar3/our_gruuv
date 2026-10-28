# frozen_string_literal: true

require "rails_helper"

RSpec.describe EngagementHealth::RequiredClarityWindows do
  let(:reference_time) { Time.zone.parse("2026-10-27 12:00:00") }

  def compute(**kwargs)
    described_class.compute(reference_time: reference_time, **kwargs)
  end

  it "is Healthy when last finalize is within the healthy window even if grace is also open" do
    result = compute(
      last_finalized_at: reference_time - 5.days,
      tenure_chain_started_at: reference_time - 10.days,
      teammate_grace_until: reference_time.to_date + 14.days
    )

    expect(result[:status]).to eq(EngagementHealth::HEALTHY)
    expect(result[:clarity_check_in_grace]).to be(false)
    expect(result[:healthy_until_at]).to eq((reference_time - 5.days).to_date + 60.days)
  end

  it "is Grey Grace Warning from max(override, tenure grace) when not Healthy" do
    result = compute(
      last_finalized_at: reference_time - 100.days,
      tenure_chain_started_at: reference_time - 1.year,
      teammate_grace_until: reference_time.to_date + 14.days
    )

    expect(result[:status]).to eq(EngagementHealth::WARNING)
    expect(result[:clarity_check_in_grace]).to be(true)
    expect(result[:grace_until_at]).to eq(reference_time.to_date + 14.days)
  end

  it "uses tenure grace through day 59 and Needs Attention on day 60 when never finalized" do
    start = reference_time.to_date - 59.days
    in_grace = compute(
      last_finalized_at: nil,
      tenure_chain_started_at: start,
      teammate_grace_until: nil
    )
    expect(in_grace[:status]).to eq(EngagementHealth::WARNING)
    expect(in_grace[:clarity_check_in_grace]).to be(true)
    expect(in_grace[:grace_until_at]).to eq(start + 59.days)

    expired = compute(
      last_finalized_at: nil,
      tenure_chain_started_at: reference_time.to_date - 60.days,
      teammate_grace_until: nil
    )
    expect(expired[:status]).to eq(EngagementHealth::NEEDS_ATTENTION)
    expect(expired[:clarity_check_in_grace]).to be(false)
  end

  it "is plain Warning between healthy and needs-attention when grace has expired" do
    result = compute(
      last_finalized_at: reference_time - 70.days,
      tenure_chain_started_at: reference_time - 1.year,
      teammate_grace_until: nil
    )

    expect(result[:status]).to eq(EngagementHealth::WARNING)
    expect(result[:clarity_check_in_grace]).to be(false)
    expect(result[:needs_attention_at]).to eq((reference_time - 70.days).to_date + 90.days)
  end

  it "stays in Grey Grace indefinitely when indefinite_tenure_grace and not Healthy" do
    result = compute(
      last_finalized_at: nil,
      tenure_chain_started_at: nil,
      teammate_grace_until: nil,
      indefinite_tenure_grace: true
    )

    expect(result[:status]).to eq(EngagementHealth::WARNING)
    expect(result[:clarity_check_in_grace]).to be(true)
    expect(result[:indefinite_tenure_grace]).to be(true)
    expect(result[:needs_attention_at]).to be_nil
    expect(result[:grace_until_at]).to be_nil
  end

  it "still prefers Healthy over indefinite tenure grace when finalize is fresh" do
    result = compute(
      last_finalized_at: reference_time - 5.days,
      tenure_chain_started_at: nil,
      teammate_grace_until: nil,
      indefinite_tenure_grace: true
    )

    expect(result[:status]).to eq(EngagementHealth::HEALTHY)
    expect(result[:clarity_check_in_grace]).to be(false)
    expect(result[:indefinite_tenure_grace]).to be(false)
  end
end

