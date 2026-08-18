# frozen_string_literal: true

module Observations
  # Feedback OGOs should include at least one constructive (negative) rating.
  # No ratings and all-positive ratings are both treated as mismatches.
  class FeedbackExpectation
    def self.mismatch?(observation)
      new(observation).mismatch?
    end

    # Feedback OGOs in +relation+ that have no constructive (negative) ratings.
    def self.without_constructive_ratings(relation)
      relation.feedback_observations.where.not(id: ObservationRating.negative.select(:observation_id))
    end

    def initialize(observation)
      @observation = observation
    end

    def mismatch?
      return false unless observation.feedback_observation_type?

      !observation.has_negative_ratings?
    end

    private

    attr_reader :observation
  end
end
