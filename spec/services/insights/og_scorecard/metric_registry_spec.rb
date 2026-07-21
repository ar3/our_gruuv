# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insights::OgScorecard::MetricRegistry do
  def metric_key(category, status)
    Insights::OgScorecard::GruuvHealthWeekCounts.metric_key(category, status)
  end

  def entries_for(title)
    described_class.grouped.find { |group| group[:title] == title }.fetch(:entries)
  end

  def expect_gruuv_health_trio(entries, category:)
    keys = entries.reject(&:separator).map(&:key)
    EngagementHealth::STATUSES.each do |status|
      expect(keys).to include(metric_key(category, status))

      entry = entries.find { |e| e.key == metric_key(category, status) }
      expect(entry.label).to be_present
      expect(entry.gruuv_status).to eq(status)
      expect(entry.gruuv_category).to eq(category)
    end

    healthy = entries.find { |entry| entry.key == metric_key(category, EngagementHealth::HEALTHY) }
    expect(healthy.threshold_hint).to be_present
  end

  describe "Check-ins group" do
    it "uses EH Required Clarity Healthy/Warning/Needs Attention instead of clear/blurred/obscured" do
      entries = entries_for("Check-ins")
      keys = entries.reject(&:separator).map(&:key)

      expect_gruuv_health_trio(entries, category: EngagementHealth::CATEGORY_REQUIRED_CLARITY)
      expect(keys).not_to include(
        "all_check_ins_clear",
        "all_check_ins_blurred",
        "all_check_ins_obscured"
      )
      healthy = entries.find { |e| e.key == metric_key(EngagementHealth::CATEGORY_REQUIRED_CLARITY, EngagementHealth::HEALTHY) }
      expect(healthy.threshold_hint).to include(
        EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS.to_s
      )
      # Prose label bakes in the live day threshold so the jargon isn't needed.
      expect(healthy.label).to include(EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS.to_s)
    end
  end

  describe "Observations group" do
    it "labels Gruuv Health rows with prose and separates OGOs Given from OGOs Received" do
      entries = entries_for("Observations")

      expect_gruuv_health_trio(entries, category: EngagementHealth::CATEGORY_OGO_GIVEN)
      expect_gruuv_health_trio(entries, category: EngagementHealth::CATEGORY_OGO_RECEIVED)

      separator_labels = entries.select(&:separator).map(&:label)
      expect(separator_labels).to include("Gruuv Health · OGOs Given", "Gruuv Health · OGOs Received")

      given_healthy = entries.find { |e| e.key == metric_key(EngagementHealth::CATEGORY_OGO_GIVEN, EngagementHealth::HEALTHY) }
      expect(given_healthy.label).to eq("Teammates that have published an OGO in the last 30 days")
    end
  end

  describe "Ability Milestones group" do
    it "includes EH Milestones Healthy/Warning/Needs Attention population rows" do
      expect_gruuv_health_trio(
        entries_for("Ability Milestones"),
        category: EngagementHealth::CATEGORY_MILESTONES
      )
    end
  end

  describe "Goals group" do
    it "includes EH Goal Confidence Healthy/Warning/Needs Attention population rows" do
      expect_gruuv_health_trio(
        entries_for("Goals"),
        category: EngagementHealth::CATEGORY_GOAL_CONFIDENCE
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
