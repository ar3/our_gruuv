# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::RequiredCheckInUrgencySort do
  describe ".sort_tuple" do
    it "orders Needs Attention before Warning" do
      a = described_class.sort_tuple(EngagementHealth::NEEDS_ATTENTION, :assignment, 10.days.ago, nil)
      b = described_class.sort_tuple(EngagementHealth::WARNING, :assignment, 10.days.ago, nil)
      expect((a <=> b)).to eq(-1)
    end

    it "maps legacy obscured/blurred keys to EH severity" do
      a = described_class.sort_tuple(:obscured, :assignment, 10.days.ago, nil)
      b = described_class.sort_tuple(:blurred, :assignment, 10.days.ago, nil)
      expect((a <=> b)).to eq(-1)
    end

    it "orders aspiration before assignment when status matches" do
      t = 5.days.ago
      a = described_class.sort_tuple(EngagementHealth::NEEDS_ATTENTION, :aspiration, t, nil)
      b = described_class.sort_tuple(EngagementHealth::NEEDS_ATTENTION, :assignment, t, nil)
      expect((a <=> b)).to eq(-1)
    end

    it "orders older finalized check-ins before newer when other keys match" do
      older = described_class.sort_tuple(EngagementHealth::WARNING, :assignment, 90.days.ago, nil)
      newer = described_class.sort_tuple(EngagementHealth::WARNING, :assignment, 5.days.ago, nil)
      expect((older <=> newer)).to eq(-1)
    end

    it "treats working_to_meet as higher urgency than other ratings when other keys match" do
      t = 10.days.ago
      wtm = described_class.sort_tuple(EngagementHealth::WARNING, :assignment, t, "working_to_meet")
      other = described_class.sort_tuple(EngagementHealth::WARNING, :assignment, t, "meeting")
      expect((wtm <=> other)).to eq(-1)
    end
  end

  describe ".parse_iso8601" do
    it "parses cache timestamps" do
      t = Time.zone.parse("2024-06-01 12:00:00")
      expect(described_class.parse_iso8601(t.iso8601)).to eq(t)
    end
  end
end
