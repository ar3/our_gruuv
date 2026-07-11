# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObservationsHealthHelper, type: :helper do
  include ActiveSupport::Testing::TimeHelpers

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
      expect(helper.observations_health_status_caption("observations_count" => 0, "never" => true)).to eq("Never published")
    end

    it "includes last published time in words when observations exist" do
      travel_to Time.zone.parse("2026-05-27 12:00:00") do
        caption = helper.observations_health_status_caption(
          "observations_count" => 2,
          "last_published_at" => 12.days.ago.iso8601
        )
        expect(caption).to eq("2 OGOs, last 12 days ago")
      end
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
