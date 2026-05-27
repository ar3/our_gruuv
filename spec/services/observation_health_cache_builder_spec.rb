# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObservationHealthCacheBuilder do
  include ActiveSupport::Testing::TimeHelpers

  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:teammate, organization: organization, first_employed_at: 1.month.ago) }
  let(:other_teammate) { create(:teammate, organization: organization, first_employed_at: 1.month.ago) }
  let(:observer) { teammate.person }

  def publish_observation!(attrs = {})
    defaults = {
      observer: attrs[:observer] || observer,
      company: organization,
      published_at: attrs.fetch(:published_at, 5.days.ago),
      deleted_at: nil,
      privacy_level: :observed_only,
      story: "Published story"
    }
    build(:observation, defaults.merge(attrs.except(:observee_teammates, :ratings))).tap do |obs|
      Array(attrs[:observee_teammates]).each { |t| obs.observees.build(teammate: t) }
      Array(attrs[:ratings]).each do |rating|
        obs.observation_ratings.build(
          rateable: create(:ability, company: organization),
          rating: rating
        )
      end
      obs.save!
    end
  end

  describe ".call" do
    it "returns payload keys for all health dimensions" do
      result = described_class.call(teammate, organization)
      expect(result.keys).to match_array(%w[given received kudos_mix rating_intensity overall_status])
    end

    it "marks given red when teammate has never published non-journal OGO" do
      result = described_class.call(teammate, organization)
      expect(result["given"]["status"]).to eq("red")
      expect(result["given"]["last_published_at"]).to be_nil
    end

    it "marks given green for a recent published observation" do
      travel_to Time.zone.parse("2026-05-27 12:00:00") do
        publish_observation!(published_at: 10.days.ago)
        result = described_class.call(teammate, organization)
        expect(result["given"]["status"]).to eq("green")
      end
    end

    it "marks given yellow when last publish is older than 30 days" do
      travel_to Time.zone.parse("2026-05-27 12:00:00") do
        publish_observation!(published_at: 45.days.ago)
        result = described_class.call(teammate, organization)
        expect(result["given"]["status"]).to eq("yellow")
      end
    end

    it "marks received green when teammate was recently observed" do
      travel_to Time.zone.parse("2026-05-27 12:00:00") do
        publish_observation!(
          observer: other_teammate.person,
          published_at: 10.days.ago,
          observee_teammates: [teammate]
        )
        result = described_class.call(teammate, organization)
        expect(result["received"]["status"]).to eq("green")
      end
    end

    it "sets overall_status to worst of given and received" do
      travel_to Time.zone.parse("2026-05-27 12:00:00") do
        publish_observation!(published_at: 10.days.ago)
        publish_observation!(
          observer: other_teammate.person,
          published_at: 45.days.ago,
          observee_teammates: [teammate]
        )
        result = described_class.call(teammate, organization)
        expect(result["given"]["status"]).to eq("green")
        expect(result["received"]["status"]).to eq("yellow")
        expect(result["overall_status"]).to eq("yellow")
      end
    end

    it "computes kudos_mix from authored observations" do
      publish_observation!(ratings: [ :agree ])
      publish_observation!(ratings: [])
      result = described_class.call(teammate, organization)
      expect(result["kudos_mix"]["kudos_count"]).to eq(1)
      expect(result["kudos_mix"]["constructive_count"]).to eq(1)
      expect(result["kudos_mix"]["band"]).to eq("below_three")
    end

    it "returns no_data kudos_mix when there are no authored observations" do
      result = described_class.call(teammate, organization)
      expect(result["kudos_mix"]["band"]).to eq("no_data")
    end

    it "computes combined rating_intensity from authored ratings" do
      publish_observation!(ratings: [ :agree, :agree, :strongly_agree ])
      result = described_class.call(teammate, organization)
      expect(result["rating_intensity"]["less_extreme_count"]).to eq(2)
      expect(result["rating_intensity"]["most_extreme_count"]).to eq(1)
      expect(result["rating_intensity"]["band"]).to eq("healthy")
    end
  end

  describe "#build_and_save" do
    it "creates or updates ObservationHealthCache" do
      publish_observation!
      expect { described_class.new(teammate, organization).build_and_save }
        .to change(ObservationHealthCache, :count).by(1)
      cache = ObservationHealthCache.find_by(teammate: teammate, organization: organization)
      expect(cache.payload["given"]["status"]).to eq("green")
      expect(cache.refreshed_at).to be_present
    end
  end
end
