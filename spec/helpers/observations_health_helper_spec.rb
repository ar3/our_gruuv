# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObservationsHealthHelper, type: :helper do
  describe "#observations_health_status_copy" do
    it "maps EngagementHealth statuses to display labels" do
      expect(helper.observations_health_status_copy(EngagementHealth::HEALTHY)).to eq("Healthy")
      expect(helper.observations_health_status_copy(EngagementHealth::WARNING)).to eq("Warning")
      expect(helper.observations_health_status_copy(EngagementHealth::NEEDS_ATTENTION)).to eq("Needs Attention")
    end
  end

  describe "#observations_health_recency_copy" do
    it "maps legacy and EH statuses to display labels" do
      expect(helper.observations_health_recency_copy("green")).to eq("Healthy")
      expect(helper.observations_health_recency_copy("yellow")).to eq("Warning")
      expect(helper.observations_health_recency_copy("red")).to eq("Needs Attention")
      expect(helper.observations_health_recency_copy(EngagementHealth::WARNING)).to eq("Warning")
    end
  end

  describe "#observations_health_status_caption" do
    it "returns never published when there is no last event" do
      expect(helper.observations_health_status_caption(
        "observations_count" => 0,
        "never" => true,
        "status" => EngagementHealth::NEEDS_ATTENTION
      )).to eq("Never published")
    end

    it "says X Healthy OGOs when every OGO is Healthy" do
      expect(helper.observations_health_status_caption(
        "status" => EngagementHealth::HEALTHY,
        "healthy_count" => 2,
        "warning_count" => 0,
        "needs_attention_count" => 0
      )).to eq("2 Healthy OGOs")
    end

    it "says X OGOs, Y Healthy when only some are Healthy" do
      expect(helper.observations_health_status_caption(
        "status" => EngagementHealth::HEALTHY,
        "healthy_count" => 1,
        "warning_count" => 1,
        "needs_attention_count" => 1
      )).to eq("3 OGOs, 1 Healthy")
    end

    it "says X Warning OGOs when every OGO is Warning" do
      expect(helper.observations_health_status_caption(
        "status" => EngagementHealth::WARNING,
        "healthy_count" => 0,
        "warning_count" => 2,
        "needs_attention_count" => 0
      )).to eq("2 Warning OGOs")
    end

    it "says X OGOs, Y Warning when only some are Warning" do
      expect(helper.observations_health_status_caption(
        "status" => EngagementHealth::WARNING,
        "healthy_count" => 0,
        "warning_count" => 1,
        "needs_attention_count" => 2
      )).to eq("3 OGOs, 1 Warning")
    end

    it "does not say 0 Warning when band count is missing but cell is Warning" do
      expect(helper.observations_health_status_caption(
        "status" => EngagementHealth::WARNING,
        "healthy_count" => 0,
        "warning_count" => 0,
        "needs_attention_count" => 11
      )).to eq("11 OGOs, 1 Warning")
    end

    it "shows only the OGO count for Needs Attention when OGOs exist" do
      expect(helper.observations_health_status_caption(
        "status" => EngagementHealth::NEEDS_ATTENTION,
        "healthy_count" => 0,
        "warning_count" => 0,
        "needs_attention_count" => 3
      )).to eq("3 OGOs")
    end
  end

  describe "#observations_health_definition_lines" do
    it "describes Gruuv Health Given/Received thresholds" do
      lines = helper.observations_health_definition_lines.join(" ")
      expect(lines).to include("Healthy / Warning / Needs Attention")
      expect(lines).to include(EngagementHealth::Thresholds::OGO_HEALTHY_WITHIN_DAYS.to_s)
      expect(lines).to include(EngagementHealth::Thresholds::OGO_NEEDS_ATTENTION_AT_DAYS.to_s)
    end
  end
end
