# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observations::HealthRecency do
  include ActiveSupport::Testing::TimeHelpers

  describe ".status_for_last_published_at" do
    it "returns red when never published" do
      expect(described_class.status_for_last_published_at(nil)).to eq("red")
    end

    it "returns green when published within 30 days" do
      travel_to Time.zone.parse("2026-05-27 12:00:00") do
        expect(described_class.status_for_last_published_at(10.days.ago)).to eq("green")
      end
    end

    it "returns yellow when last published more than 30 days ago" do
      travel_to Time.zone.parse("2026-05-27 12:00:00") do
        expect(described_class.status_for_last_published_at(45.days.ago)).to eq("yellow")
      end
    end
  end

  describe ".payload_for_scope" do
    let(:organization) { create(:organization, :company) }
    let(:teammate) { create(:teammate, organization: organization, first_employed_at: 1.month.ago) }

    it "includes observations_count from the scope" do
      build(:observation, observer: teammate.person, company: organization, published_at: 5.days.ago, story: "Hi", privacy_level: :observed_only).tap do |obs|
        obs.observees.clear
        obs.save!
      end
      scope = Observations::HealthScopes.given_scope(teammate, organization)
      payload = described_class.payload_for_scope(scope)
      expect(payload["observations_count"]).to eq(1)
      expect(payload["status"]).to eq("green")
    end
  end

  describe ".overall_status" do
    it "returns the worse of given and received" do
      expect(described_class.overall_status("green", "yellow")).to eq("yellow")
      expect(described_class.overall_status("green", "red")).to eq("red")
      expect(described_class.overall_status("yellow", "red")).to eq("red")
      expect(described_class.overall_status("green", "green")).to eq("green")
    end
  end
end
