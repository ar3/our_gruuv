# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObservationHealthCache, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:teammate) }
    it { is_expected.to belong_to(:organization) }
  end

  describe "validations" do
    subject { build(:observation_health_cache) }

    it { is_expected.to validate_presence_of(:payload) }

    it "validates uniqueness of teammate scoped to organization" do
      existing = create(:observation_health_cache)
      duplicate = build(:observation_health_cache, teammate: existing.teammate, organization: existing.organization)
      expect(duplicate).not_to be_valid
    end
  end

  describe "payload accessors" do
    let(:cache) { build(:observation_health_cache) }

    it "reads nested payload sections" do
      expect(cache.payload_given["status"]).to eq("red")
      expect(cache.payload_kudos_mix["band"]).to eq("no_data")
      expect(cache.overall_status).to eq("red")
    end
  end
end
