# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insights::OgScorecard::MetricRegistry do
  def metric_key(category, status)
    Insights::OgScorecard::GruuvHealthWeekCounts.metric_key(category, status)
  end

  def entries_for(title)
    described_class.grouped.find { |group| group[:title] == title }.fetch(:entries)
  end

  def expect_gruuv_health_trio(entries, category:, metric_name:)
    keys = entries.reject(&:separator).map(&:key)
    EngagementHealth::STATUSES.each do |status|
      expect(keys).to include(metric_key(category, status))
    end

    healthy = entries.find { |entry| entry.key == metric_key(category, EngagementHealth::HEALTHY) }
    expect(healthy.label).to include("Healthy")
    expect(healthy.label).to include(metric_name)
    expect(healthy.threshold_hint).to be_present
  end

  describe "Check-ins group" do
    it "uses EH Required Clarity Healthy/Warning/Needs Attention instead of clear/blurred/obscured" do
      entries = entries_for("Check-ins")
      keys = entries.reject(&:separator).map(&:key)

      expect_gruuv_health_trio(entries, category: EngagementHealth::CATEGORY_REQUIRED_CLARITY, metric_name: "Required Clarity")
      expect(keys).not_to include(
        "all_check_ins_clear",
        "all_check_ins_blurred",
        "all_check_ins_obscured"
      )
      expect(entries.find { |e| e.key == metric_key(EngagementHealth::CATEGORY_REQUIRED_CLARITY, EngagementHealth::HEALTHY) }
        .threshold_hint).to include(
          EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS.to_s
        )
    end
  end

  describe "Ability Milestones group" do
    it "includes EH Milestones Healthy/Warning/Needs Attention population rows" do
      expect_gruuv_health_trio(
        entries_for("Ability Milestones"),
        category: EngagementHealth::CATEGORY_MILESTONES,
        metric_name: "Milestones"
      )
    end
  end

  describe "Goals group" do
    it "includes EH Goal Confidence Healthy/Warning/Needs Attention population rows" do
      expect_gruuv_health_trio(
        entries_for("Goals"),
        category: EngagementHealth::CATEGORY_GOAL_CONFIDENCE,
        metric_name: "Goal Confidence"
      )
    end
  end

  describe "all Gruuv Health categories" do
    it "registers Healthy/Warning/Needs Attention for every EngagementHealth category" do
      keys = described_class.keys
      EngagementHealth::CATEGORIES.each do |category|
        EngagementHealth::STATUSES.each do |status|
          expect(keys).to include(metric_key(category, status))
        end
      end
      expect(keys.count { |key| key.start_with?(Insights::OgScorecard::GruuvHealthWeekCounts::METRIC_KEY_PREFIX) })
        .to eq(EngagementHealth::CATEGORIES.size * EngagementHealth::STATUSES.size)
    end
  end
end
