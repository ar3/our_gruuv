# frozen_string_literal: true

module Observations
  class UnpublishService
    def self.call(observation)
      new(observation).call
    end

    def initialize(observation)
      @observation = observation
    end

    def call
      return false unless observation.published?

      observation.update_column(:published_at, nil)
      HealthCacheRefresh.enqueue_for_observation(observation)
      true
    end

    private

    attr_reader :observation
  end
end
