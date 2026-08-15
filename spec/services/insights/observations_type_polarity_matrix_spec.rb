# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insights::ObservationsTypePolarityMatrix do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }

  def published_observation(attrs = {})
    create(
      :observation,
      :published,
      :public_to_company,
      {
        observer: observer,
        company: company,
        observation_type: :generic,
        observed_at: Time.current
      }.merge(attrs)
    )
  end

  def add_rating(observation, rating_value)
    create(
      :observation_rating,
      observation: observation,
      rating: rating_value,
      rateable: create(:ability, company: company)
    )
  end

  describe ".polarity_for" do
    it "returns no_ratings when there are no ratings" do
      obs = published_observation
      expect(described_class.polarity_for(obs)).to eq("no_ratings")
    end

    it "returns no_ratings when ratings are N/A only" do
      obs = published_observation
      add_rating(obs, :na)
      expect(described_class.polarity_for(obs.reload)).to eq("no_ratings")
    end

    it "returns all_positive when only positive ratings exist" do
      obs = published_observation
      add_rating(obs, :agree)
      expect(described_class.polarity_for(obs.reload)).to eq("all_positive")
    end

    it "returns all_negative when only negative ratings exist" do
      obs = published_observation
      add_rating(obs, :disagree)
      expect(described_class.polarity_for(obs.reload)).to eq("all_negative")
    end

    it "returns mix when both positive and negative ratings exist" do
      obs = published_observation
      add_rating(obs, :agree)
      add_rating(obs, :disagree)
      expect(described_class.polarity_for(obs.reload)).to eq("mix")
    end
  end

  describe ".call" do
    it "builds a full 4×4 matrix with counts, percents, heatmap, and stacked series" do
      generic_none = published_observation(observation_type: :generic)
      kudos_pos = published_observation(observation_type: :kudos)
      add_rating(kudos_pos, :strongly_agree)
      feedback_none = published_observation(observation_type: :feedback)
      note_mix = published_observation(observation_type: :quick_note)
      add_rating(note_mix, :agree)
      add_rating(note_mix, :strongly_disagree)

      observations = Observation.where(id: [generic_none, kudos_pos, feedback_none, note_mix].map(&:id))
        .includes(:observation_ratings)
        .to_a

      result = described_class.call(observations)

      expect(result[:total]).to eq(4)
      expect(result[:counts]["generic"]["no_ratings"]).to eq(1)
      expect(result[:counts]["kudos"]["all_positive"]).to eq(1)
      expect(result[:counts]["feedback"]["no_ratings"]).to eq(1)
      expect(result[:counts]["quick_note"]["mix"]).to eq(1)

      heatmap_point = result[:heatmap][:data].find { |p| p[:x] == 0 && p[:y] == 0 }
      expect(heatmap_point[:value]).to eq(1)
      expect(heatmap_point[:pct]).to eq(25.0)

      stacked_no_ratings = result[:stacked][:series].find { |s| s[:name] == "No ratings" }
      expect(stacked_no_ratings[:data]).to eq([1, 0, 1, 0])
      expect(stacked_no_ratings[:pct_data]).to eq([25.0, 0.0, 25.0, 0.0])
    end

    it "returns zero-filled matrix for empty input" do
      result = described_class.call([])
      expect(result[:total]).to eq(0)
      expect(result[:heatmap][:data].size).to eq(16)
      expect(result[:heatmap][:data].map { |p| p[:value] }).to all(eq(0))
      expect(result[:stacked][:series].size).to eq(4)
    end
  end
end
