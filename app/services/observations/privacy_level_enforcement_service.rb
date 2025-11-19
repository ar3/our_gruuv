module Observations
  class PrivacyLevelEnforcementService
    def self.call(observation)
      new(observation).call
    end

    def initialize(observation)
      @observation = observation
    end

    def call
      return false unless should_enforce_privacy?

      @observation.update_column(:privacy_level, 'observed_and_managers')
      true
    end

    private

    attr_reader :observation

    def should_enforce_privacy?
      return false unless observation.privacy_level == 'public_observation'
      
      # Reload ratings association to ensure we check saved ratings
      observation.observation_ratings.reload
      observation.has_negative_ratings?
    end
  end
end

