# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observations::FeedbackExpectation do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:ability) { create(:ability, company: company) }

  def build_feedback_observation
    create(:observation, observer: observer, company: company, observation_type: :feedback, created_as_type: "feedback")
  end

  describe ".mismatch?" do
    it "returns false for kudos observations" do
      observation = create(:observation, observer: observer, company: company, observation_type: :kudos)
      expect(described_class.mismatch?(observation)).to be false
    end

    it "returns true for feedback with no ratings" do
      observation = build_feedback_observation
      expect(described_class.mismatch?(observation)).to be true
    end

    it "returns true for feedback with only positive ratings" do
      observation = build_feedback_observation
      create(:observation_rating, observation: observation, rateable: ability, rating: :agree)
      expect(described_class.mismatch?(observation)).to be true
    end

    it "returns true for feedback with only N/A ratings" do
      observation = build_feedback_observation
      create(:observation_rating, observation: observation, rateable: ability, rating: :na)
      expect(described_class.mismatch?(observation)).to be true
    end

    it "returns false for feedback with at least one constructive rating" do
      observation = build_feedback_observation
      create(:observation_rating, observation: observation, rateable: ability, rating: :disagree)
      expect(described_class.mismatch?(observation)).to be false
    end

    it "returns false for feedback with mixed positive and constructive ratings" do
      observation = build_feedback_observation
      assignment = create(:assignment, company: company)
      create(:observation_rating, observation: observation, rateable: ability, rating: :agree)
      create(:observation_rating, observation: observation, rateable: assignment, rating: :strongly_disagree)
      expect(described_class.mismatch?(observation)).to be false
    end
  end
end
