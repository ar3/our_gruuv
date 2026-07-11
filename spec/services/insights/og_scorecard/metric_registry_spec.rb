# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insights::OgScorecard::MetricRegistry do
  describe "Check-ins group" do
    let(:check_ins_entries) do
      described_class.grouped.find { |group| group[:title] == "Check-ins" }.fetch(:entries)
    end

    it "uses EH Required Clarity Healthy/Warning/Needs Attention instead of clear/blurred/obscured" do
      keys = check_ins_entries.reject(&:separator).map(&:key)

      expect(keys).to include(
        Insights::OgScorecard::GruuvHealthWeekCounts.metric_key(
          EngagementHealth::CATEGORY_REQUIRED_CLARITY,
          EngagementHealth::HEALTHY
        ),
        Insights::OgScorecard::GruuvHealthWeekCounts.metric_key(
          EngagementHealth::CATEGORY_REQUIRED_CLARITY,
          EngagementHealth::WARNING
        ),
        Insights::OgScorecard::GruuvHealthWeekCounts.metric_key(
          EngagementHealth::CATEGORY_REQUIRED_CLARITY,
          EngagementHealth::NEEDS_ATTENTION
        )
      )
      expect(keys).not_to include(
        "all_check_ins_clear",
        "all_check_ins_blurred",
        "all_check_ins_obscured"
      )

      healthy = check_ins_entries.find do |entry|
        entry.key == Insights::OgScorecard::GruuvHealthWeekCounts.metric_key(
          EngagementHealth::CATEGORY_REQUIRED_CLARITY,
          EngagementHealth::HEALTHY
        )
      end
      expect(healthy.label).to include("Healthy")
      expect(healthy.label).to include("Required Clarity")
      expect(healthy.threshold_hint).to include(
        EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS.to_s
      )
    end
  end
end
