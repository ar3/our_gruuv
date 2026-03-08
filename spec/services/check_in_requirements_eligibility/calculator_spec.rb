# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckInRequirementsEligibility::Calculator do
  let(:minimum_months) { 12 }
  let(:meeting_threshold_pct) { 80.0 }
  let(:exceeding_threshold_pct) { 20.0 }

  def status_list(*symbols)
    symbols.map { |s| { "status" => s.to_s } }
  end

  describe "#call" do
    it "returns unknown when all months in range have no finalized check-in" do
      by_row = { 1 => status_list(:none, :none, :none) }
      result = described_class.new(
        row_ids: [1],
        monthly_statuses_by_row_id: by_row,
        minimum_months: 3,
        meeting_threshold_pct: meeting_threshold_pct,
        exceeding_threshold_pct: exceeding_threshold_pct
      ).call
      expect(result.row_result_by_id(1).category).to eq(CheckInRequirementsEligibility::RowCategory::UNKNOWN)
    end

    it "returns miss when any month in range is working_to_meet" do
      by_row = { 1 => status_list(:meeting, :working_to_meet, :exceeding) }
      result = described_class.new(
        row_ids: [1],
        monthly_statuses_by_row_id: by_row,
        minimum_months: 3,
        meeting_threshold_pct: meeting_threshold_pct,
        exceeding_threshold_pct: exceeding_threshold_pct
      ).call
      expect(result.row_result_by_id(1).category).to eq(CheckInRequirementsEligibility::RowCategory::MISS)
    end

    it "returns exceeding when all months in range are exceeding" do
      by_row = { 1 => status_list(:exceeding, :exceeding, :exceeding) }
      result = described_class.new(
        row_ids: [1],
        monthly_statuses_by_row_id: by_row,
        minimum_months: 3,
        meeting_threshold_pct: meeting_threshold_pct,
        exceeding_threshold_pct: exceeding_threshold_pct
      ).call
      expect(result.row_result_by_id(1).category).to eq(CheckInRequirementsEligibility::RowCategory::EXCEEDING)
    end

    it "returns maybe_exceeding when at least one exceeding and no working_to_meet and not all exceeding" do
      by_row = { 1 => status_list(:exceeding, :meeting, :none) }
      result = described_class.new(
        row_ids: [1],
        monthly_statuses_by_row_id: by_row,
        minimum_months: 3,
        meeting_threshold_pct: meeting_threshold_pct,
        exceeding_threshold_pct: exceeding_threshold_pct
      ).call
      expect(result.row_result_by_id(1).category).to eq(CheckInRequirementsEligibility::RowCategory::MAYBE_EXCEEDING)
    end

    it "returns meeting when all months in range are meeting" do
      by_row = { 1 => status_list(:meeting, :meeting, :meeting) }
      result = described_class.new(
        row_ids: [1],
        monthly_statuses_by_row_id: by_row,
        minimum_months: 3,
        meeting_threshold_pct: meeting_threshold_pct,
        exceeding_threshold_pct: exceeding_threshold_pct
      ).call
      expect(result.row_result_by_id(1).category).to eq(CheckInRequirementsEligibility::RowCategory::MEETING)
    end

    it "returns maybe_meeting when some months none and some meeting, no working_to_meet or exceeding" do
      by_row = { 1 => status_list(:none, :meeting, :meeting) }
      result = described_class.new(
        row_ids: [1],
        monthly_statuses_by_row_id: by_row,
        minimum_months: 3,
        meeting_threshold_pct: meeting_threshold_pct,
        exceeding_threshold_pct: exceeding_threshold_pct
      ).call
      expect(result.row_result_by_id(1).category).to eq(CheckInRequirementsEligibility::RowCategory::MAYBE_MEETING)
    end

    it "uses last minimum_months of the 12-month window" do
      # 12 months: first 9 meeting, last 3 exceeding — only last 3 are used when minimum_months is 3
      twelve = ([:meeting] * 9) + [:exceeding, :exceeding, :exceeding]
      by_row = { 1 => twelve.map { |s| { "status" => s.to_s } } }
      result = described_class.new(
        row_ids: [1],
        monthly_statuses_by_row_id: by_row,
        minimum_months: 3,
        meeting_threshold_pct: meeting_threshold_pct,
        exceeding_threshold_pct: exceeding_threshold_pct
      ).call
      expect(result.row_result_by_id(1).category).to eq(CheckInRequirementsEligibility::RowCategory::EXCEEDING)
    end

    it "builds summary with counts and percentages" do
      by_row = {
        1 => status_list(:exceeding, :exceeding),
        2 => status_list(:meeting, :meeting),
        3 => status_list(:working_to_meet)
      }
      result = described_class.new(
        row_ids: [1, 2, 3],
        monthly_statuses_by_row_id: by_row,
        minimum_months: 2,
        meeting_threshold_pct: 66.0,
        exceeding_threshold_pct: 33.0
      ).call
      summary = result.summary
      expect(summary.total).to eq(3)
      expect(summary.count_exceeding).to eq(1)
      expect(summary.count_meeting).to eq(1)
      expect(summary.count_miss).to eq(1)
      expect(summary.full_exceed_pct).to eq(33.3)
      expect(summary.exceed_plus_maybe_exceed_pct).to eq(33.3)
      # full_meet = exceeding + maybe_exceeding + meeting = 2; meet_plus_maybe = + maybe_meeting = 2
      expect(summary.full_meet_pct).to eq(66.7)
      expect(summary.meet_plus_maybe_meet_pct).to eq(66.7)
    end
  end
end
