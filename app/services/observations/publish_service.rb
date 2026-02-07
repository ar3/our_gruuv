module Observations
  class PublishService
    def self.call(observation)
      new(observation).call
    end

    def initialize(observation)
      @observation = observation
    end

    def call
      # Remove all unrated (na) ratings before publishing
      @observation.observation_ratings.neutral.destroy_all
      
    # Set published_at timestamp (this will trigger validation)
    @observation.update!(published_at: Time.current)
    
    # Enforce privacy level if needed
    privacy_changed = PrivacyLevelEnforcementService.call(@observation)
    
    # Kudos points are awarded by the observer in the nudge (award_kudos), not on publish
    privacy_changed
  end

  private

  attr_reader :observation
end
end

