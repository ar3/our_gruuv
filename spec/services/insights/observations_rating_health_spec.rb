# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insights::ObservationsRatingHealth do
  describe ".rounded_ratio_display" do
    it "returns 0:0 when both sides are zero" do
      expect(described_class.rounded_ratio_display(0, 0)).to eq("0:0")
    end

    it "returns left:0 when right is zero" do
      expect(described_class.rounded_ratio_display(5, 0)).to eq("5:0")
    end

    it "returns 0:right when left is zero" do
      expect(described_class.rounded_ratio_display(0, 4)).to eq("0:4")
    end

    it "rounds fractional ratios to whole N:1" do
      expect(described_class.rounded_ratio_display(9, 3)).to eq("3:1")
      expect(described_class.rounded_ratio_display(10, 3)).to eq("3:1")
    end
  end

  describe ".kudos_constructive_ratio_band" do
    it "returns :no_data when both counts are zero" do
      expect(described_class.kudos_constructive_ratio_band(0, 0)).to eq(:no_data)
    end

    it "returns :above_seven when constructive is zero and kudos is positive" do
      expect(described_class.kudos_constructive_ratio_band(3, 0)).to eq(:above_seven)
    end

    it "returns :above_seven when ratio is greater than 7" do
      expect(described_class.kudos_constructive_ratio_band(8, 1)).to eq(:above_seven)
    end

    it "returns :healthy when ratio is between 3 and 7 inclusive" do
      expect(described_class.kudos_constructive_ratio_band(6, 2)).to eq(:healthy)
      expect(described_class.kudos_constructive_ratio_band(21, 7)).to eq(:healthy)
    end

    it "returns :below_three when ratio is below 3" do
      expect(described_class.kudos_constructive_ratio_band(2, 1)).to eq(:below_three)
    end
  end

  describe ".two_tier_ratio_band" do
    it "returns :no_data when both sides are zero" do
      expect(described_class.two_tier_ratio_band(0, 0)).to eq(:no_data)
    end

    it "returns :above_five when right is zero and left is positive" do
      expect(described_class.two_tier_ratio_band(6, 0)).to eq(:above_five)
    end

    it "returns :below_one when left is zero and right is positive" do
      expect(described_class.two_tier_ratio_band(0, 4)).to eq(:below_one)
    end

    it "returns :above_five when ratio is greater than 5" do
      expect(described_class.two_tier_ratio_band(12, 2)).to eq(:above_five)
    end

    it "returns :below_one when ratio is less than 1" do
      expect(described_class.two_tier_ratio_band(2, 5)).to eq(:below_one)
    end

    it "returns :healthy when ratio is between 1 and 5 inclusive" do
      expect(described_class.two_tier_ratio_band(9, 3)).to eq(:healthy)
      expect(described_class.two_tier_ratio_band(5, 5)).to eq(:healthy)
    end
  end

  describe ".combined_rating_intensity_band" do
    it "uses less extreme vs most extreme counts" do
      counts = { strongly_agree: 1, agree: 9, disagree: 6, strongly_disagree: 2 }
      expect(described_class.combined_rating_intensity_band(counts)).to eq(:healthy)
    end
  end

  describe ".kudos_mix_side" do
    let(:company) { create(:company) }
    let(:observer) { create(:person) }

    def build_observation(ratings)
      build(:observation, observer: observer, company: company, published_at: 1.day.ago).tap do |obs|
        ratings.each do |rating|
          obs.observation_ratings.build(
            rateable: create(:ability, company: company),
            rating: rating
          )
        end
      end
    end

    it "returns :kudos when there is positive rating and no negative" do
      observation = build_observation([ :agree ])
      expect(described_class.kudos_mix_side(observation)).to eq(:kudos)
    end

    it "returns :constructive when there are no ratings" do
      observation = build_observation([])
      expect(described_class.kudos_mix_side(observation)).to eq(:constructive)
    end

    it "returns :constructive when there is any negative rating" do
      observation = build_observation([ :agree, :disagree ])
      expect(described_class.kudos_mix_side(observation)).to eq(:constructive)
    end

    it "returns :constructive when only negative ratings exist" do
      observation = build_observation([ :strongly_disagree ])
      expect(described_class.kudos_mix_side(observation)).to eq(:constructive)
    end

    it "ignores N/A ratings for positive/negative detection" do
      observation = build_observation([ :na, :agree ])
      expect(described_class.kudos_mix_side(observation)).to eq(:kudos)
    end
  end

  describe ".kudos_constructive_counts_from_observations" do
    let(:company) { create(:company) }
    let(:observer) { create(:person) }

    it "tallies per-observation kudos vs constructive sides" do
      kudos_obs = build(:observation, observer: observer, company: company, published_at: 1.day.ago).tap do |obs|
        obs.observation_ratings.build(rateable: create(:ability, company: company), rating: :agree)
      end
      constructive_obs = build(:observation, observer: observer, company: company, published_at: 1.day.ago)
      tallies = described_class.kudos_constructive_counts_from_observations([ kudos_obs, constructive_obs ])
      expect(tallies).to eq({ kudos: 1, constructive: 1 })
    end
  end

  describe ".kudos_constructive_band_for_observations" do
    it "applies ratio bands to observation-level tallies" do
      observations = Array.new(8) do
        build(:observation, company: create(:company), observer: create(:person), published_at: 1.day.ago).tap do |obs|
          obs.observation_ratings.build(rateable: create(:ability, company: obs.company), rating: :agree)
        end
      end
      expect(described_class.kudos_constructive_band_for_observations(observations)).to eq(:above_seven)
    end
  end

  describe ".org_rating_health_ratio_rows" do
    it "builds three ratio rows with bands and display ratios" do
      rows = described_class.org_rating_health_ratio_rows(
        "strongly_agree" => 2,
        "agree" => 6,
        "disagree" => 3,
        "strongly_disagree" => 1
      )

      expect(rows.size).to eq(3)
      expect(rows[0][:name]).to eq("Kudos : Constructive")
      expect(rows[0][:display_ratio]).to eq("2:1")
      expect(rows[0][:kudos_constructive_band]).to eq(:below_three)
      expect(rows[1][:solid_exceptional_band]).to eq(:healthy)
      expect(rows[2][:misaligned_concerning_band]).to eq(:healthy)
    end
  end

  describe ".rating_counts_from_observations" do
    let(:company) { create(:company) }
    let(:observer) { create(:person) }

    it "sums ratings across observations" do
      obs = build(:observation, observer: observer, company: company, published_at: 1.day.ago)
      ability = create(:ability, company: company)
      obs.observation_ratings.build(rateable: ability, rating: :strongly_agree)
      obs.observation_ratings.build(rateable: create(:assignment, company: company), rating: :disagree)

      counts = described_class.rating_counts_from_observations([ obs ])
      expect(counts).to eq(
        strongly_agree: 1,
        agree: 0,
        disagree: 1,
        strongly_disagree: 0
      )
    end
  end
end
