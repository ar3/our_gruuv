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
      
      # Process highlights points (outside main flow to not block publishing)
      process_highlights_points
      
      privacy_changed
    end

    private

    attr_reader :observation

    def process_highlights_points
      return unless observation.observees.any?
      
      result = Highlights::ProcessObservationPointsService.call(observation: observation)
      
      if result.ok?
        Rails.logger.info "Processed highlights points for observation #{observation.id}: #{result.value.count} transactions"
      else
        # Log but don't fail - highlights points are a bonus feature
        Rails.logger.info "Highlights points not processed for observation #{observation.id}: #{result.error}"
      end
    rescue => e
      # Catch any errors to prevent them from affecting the main flow
      Rails.logger.error "Error processing highlights points: #{e.message}"
    end
  end
end

