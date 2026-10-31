# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationSlackSearches::ChannelVisibility do
  it "classifies public channels" do
    expect(
      described_class.classify(
        "channel_id" => "C123",
        "channel_is_private" => false,
        "channel_is_mpim" => false,
        "match_type" => "message"
      )
    ).to eq(SlackPossibleObservation::VISIBILITY_PUBLIC)
  end

  it "classifies private channels, MPIMs, and DMs as private_or_dm" do
    expect(described_class.classify("channel_id" => "C1", "channel_is_private" => true))
      .to eq(SlackPossibleObservation::VISIBILITY_PRIVATE_OR_DM)
    expect(described_class.classify("channel_id" => "C1", "channel_is_mpim" => true, "channel_is_private" => false))
      .to eq(SlackPossibleObservation::VISIBILITY_PRIVATE_OR_DM)
    expect(described_class.classify("channel_id" => "D123", "match_type" => "im"))
      .to eq(SlackPossibleObservation::VISIBILITY_PRIVATE_OR_DM)
  end

  it "defaults to private_or_dm when visibility flags are missing" do
    expect(described_class.classify("channel_id" => "C123"))
      .to eq(SlackPossibleObservation::VISIBILITY_PRIVATE_OR_DM)
  end
end
