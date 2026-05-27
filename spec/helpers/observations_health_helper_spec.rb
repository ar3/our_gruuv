# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObservationsHealthHelper, type: :helper do
  include ActiveSupport::Testing::TimeHelpers

  describe "#observations_health_recency_copy" do
    it "maps recency statuses to display labels" do
      expect(helper.observations_health_recency_copy("green")).to eq("Healthy")
      expect(helper.observations_health_recency_copy("yellow")).to eq("Stale")
      expect(helper.observations_health_recency_copy("red")).to eq("Never")
    end
  end

  describe "#observations_health_recency_caption" do
    it "returns only the count when there are no observations" do
      expect(helper.observations_health_recency_caption("observations_count" => 0)).to eq("0 OGOs")
    end

    it "includes last published time in words when observations exist" do
      travel_to Time.zone.parse("2026-05-27 12:00:00") do
        caption = helper.observations_health_recency_caption(
          "observations_count" => 2,
          "last_published_at" => 12.days.ago.iso8601
        )
        expect(caption).to eq("2 OGOs, last 12 days ago")
      end
    end
  end
end
