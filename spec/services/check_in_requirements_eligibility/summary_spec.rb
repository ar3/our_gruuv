# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckInRequirementsEligibility::Summary do
  describe "percentages and display status" do
    it "computes exceed/meet percentages from category counts" do
      summary = described_class.new(
        count_exceeding: 2,
        count_maybe_exceeding: 1,
        count_meeting: 1,
        count_maybe_meeting: 0,
        count_miss: 0,
        count_unknown: 0,
        meeting_threshold_pct: 80.0,
        exceeding_threshold_pct: 20.0
      )
      expect(summary.total).to eq(4)
      expect(summary.full_exceed_pct).to eq(50.0)   # 2/4
      expect(summary.exceed_plus_maybe_exceed_pct).to eq(75.0)  # 3/4
      expect(summary.full_meet_pct).to eq(100.0)     # exceeding + maybe_exceeding + meeting = 4
      expect(summary.meet_plus_maybe_meet_pct).to eq(100.0)
    end

    it "returns OK icon when first percentage meets threshold" do
      summary = described_class.new(
        count_exceeding: 3,
        count_maybe_exceeding: 0,
        count_meeting: 0,
        count_maybe_meeting: 0,
        count_miss: 0,
        count_unknown: 1,
        meeting_threshold_pct: 50.0,
        exceeding_threshold_pct: 50.0
      )
      expect(summary.exceed_status_icon).to eq("✅")
      # full_meet = 3 (exceeding), meet_plus_maybe = 3, so 75% >= 50% for both thresholds
      expect(summary.overall_eligible).to be true
    end

    it "returns MAYBE_OK icon when second percentage meets threshold but first does not" do
      summary = described_class.new(
        count_exceeding: 0,
        count_maybe_exceeding: 2,
        count_meeting: 0,
        count_maybe_meeting: 0,
        count_miss: 0,
        count_unknown: 0,
        meeting_threshold_pct: 80.0,
        exceeding_threshold_pct: 50.0
      )
      expect(summary.exceed_plus_maybe_exceed_pct).to eq(100.0)
      expect(summary.full_exceed_pct).to eq(0.0)
      expect(summary.exceed_status_icon).to eq("⁉️✅")
    end

    it "returns NOT_MET icon when neither percentage meets threshold" do
      summary = described_class.new(
        count_exceeding: 0,
        count_maybe_exceeding: 0,
        count_meeting: 1,
        count_maybe_meeting: 1,
        count_miss: 2,
        count_unknown: 0,
        meeting_threshold_pct: 80.0,
        exceeding_threshold_pct: 20.0
      )
      expect(summary.exceed_status_icon).to eq("🚧")
      expect(summary.meet_status_icon).to eq("🚧")
      expect(summary.overall_eligible).to be false
      expect(summary.overall_eligibility_status).to eq(:working_to_meet_requirements)
    end
  end

  describe "0% threshold display (always passing)" do
    it "shows meeting as passing when meeting threshold is 0%" do
      summary = described_class.new(
        count_exceeding: 0,
        count_maybe_exceeding: 0,
        count_meeting: 0,
        count_maybe_meeting: 0,
        count_miss: 4,
        count_unknown: 0,
        meeting_threshold_pct: 0,
        exceeding_threshold_pct: 20.0
      )
      expect(summary.meet_display_status).to eq(CheckInRequirementsEligibility::DisplayStatus::OK)
      expect(summary.meet_status_icon).to eq("✅")
    end

    it "shows exceeding as passing when exceeding threshold is 0%" do
      summary = described_class.new(
        count_exceeding: 0,
        count_maybe_exceeding: 0,
        count_meeting: 0,
        count_maybe_meeting: 0,
        count_miss: 4,
        count_unknown: 0,
        meeting_threshold_pct: 80.0,
        exceeding_threshold_pct: 0
      )
      expect(summary.exceed_display_status).to eq(CheckInRequirementsEligibility::DisplayStatus::OK)
      expect(summary.exceed_status_icon).to eq("✅")
    end

    it "shows both as passing when both thresholds are 0%" do
      summary = described_class.new(
        count_exceeding: 0,
        count_maybe_exceeding: 0,
        count_meeting: 0,
        count_maybe_meeting: 0,
        count_miss: 4,
        count_unknown: 0,
        meeting_threshold_pct: 0,
        exceeding_threshold_pct: 0
      )
      expect(summary.meet_display_status).to eq(CheckInRequirementsEligibility::DisplayStatus::OK)
      expect(summary.exceed_display_status).to eq(CheckInRequirementsEligibility::DisplayStatus::OK)
      expect(summary.overall_eligibility_status).to eq(:eligible)
      expect(summary.overall_eligible).to be true
    end
  end

  describe "overall eligibility determination" do
    it "is eligible only when both meeting and exceeding are passing" do
      summary = described_class.new(
        count_exceeding: 4,
        count_maybe_exceeding: 0,
        count_meeting: 0,
        count_maybe_meeting: 0,
        count_miss: 0,
        count_unknown: 0,
        meeting_threshold_pct: 80.0,
        exceeding_threshold_pct: 20.0
      )
      expect(summary.meet_display_status).to eq(CheckInRequirementsEligibility::DisplayStatus::OK)
      expect(summary.exceed_display_status).to eq(CheckInRequirementsEligibility::DisplayStatus::OK)
      expect(summary.overall_eligibility_status).to eq(:eligible)
      expect(summary.overall_eligible).to be true
    end

    it "is on_track_to_eligible when meeting is passing but exceeding is on-track" do
      summary = described_class.new(
        count_exceeding: 0,
        count_maybe_exceeding: 4,
        count_meeting: 0,
        count_maybe_meeting: 0,
        count_miss: 0,
        count_unknown: 0,
        meeting_threshold_pct: 0,
        exceeding_threshold_pct: 50.0
      )
      expect(summary.meet_display_status).to eq(CheckInRequirementsEligibility::DisplayStatus::OK)
      expect(summary.exceed_display_status).to eq(CheckInRequirementsEligibility::DisplayStatus::MAYBE_OK)
      expect(summary.overall_eligibility_status).to eq(:on_track_to_eligible)
      expect(summary.overall_eligible).to be false
    end

    it "is on_track_to_eligible when exceeding is passing but meeting is on-track" do
      summary = described_class.new(
        count_exceeding: 4,
        count_maybe_exceeding: 0,
        count_meeting: 0,
        count_maybe_meeting: 4,
        count_miss: 0,
        count_unknown: 0,
        meeting_threshold_pct: 80.0,
        exceeding_threshold_pct: 0
      )
      expect(summary.exceed_display_status).to eq(CheckInRequirementsEligibility::DisplayStatus::OK)
      expect(summary.meet_display_status).to eq(CheckInRequirementsEligibility::DisplayStatus::MAYBE_OK)
      expect(summary.overall_eligibility_status).to eq(:on_track_to_eligible)
      expect(summary.overall_eligible).to be false
    end

    it "is working_to_meet_requirements when either meeting or exceeding is missing" do
      summary = described_class.new(
        count_exceeding: 0,
        count_maybe_exceeding: 0,
        count_meeting: 2,
        count_maybe_meeting: 0,
        count_miss: 2,
        count_unknown: 0,
        meeting_threshold_pct: 80.0,
        exceeding_threshold_pct: 20.0
      )
      expect(summary.meet_display_status).to eq(CheckInRequirementsEligibility::DisplayStatus::NOT_MET)
      expect(summary.exceed_display_status).to eq(CheckInRequirementsEligibility::DisplayStatus::NOT_MET)
      expect(summary.overall_eligibility_status).to eq(:working_to_meet_requirements)
      expect(summary.overall_eligible).to be false
    end

    it "is working_to_meet_requirements when meeting is missing and exceeding is passing" do
      # 4 exceeding, 2 miss → exceed 66.7% (passing at 20%), meet 66.7% (missing at 80%)
      summary = described_class.new(
        count_exceeding: 4,
        count_maybe_exceeding: 0,
        count_meeting: 0,
        count_maybe_meeting: 0,
        count_miss: 2,
        count_unknown: 0,
        meeting_threshold_pct: 80.0,
        exceeding_threshold_pct: 20.0
      )
      expect(summary.exceed_display_status).to eq(CheckInRequirementsEligibility::DisplayStatus::OK)
      expect(summary.meet_display_status).to eq(CheckInRequirementsEligibility::DisplayStatus::NOT_MET)
      expect(summary.overall_eligibility_status).to eq(:working_to_meet_requirements)
      expect(summary.overall_eligible).to be false
    end
  end
end
