module Observations
  class AddObserveeService
    def initialize(observation:, teammate_id:)
      @observation = observation
      @teammate_id = teammate_id
    end

    def call
      # Ensure observation is loaded with company when already saved
      @observation.reload if @observation.persisted?

      observee = find_or_add_observee
      return observee unless observee

      # Keep Assignment/Ability ratings as the intersection across all observees
      SyncObserveeRateablesService.new(observation: @observation).call

      observee
    end

    private

    attr_reader :observation, :teammate_id

    def find_or_add_observee
      existing = existing_observee
      return existing if existing

      if @observation.persisted?
        @observation.observees.create!(teammate_id: @teammate_id)
      else
        @observation.observees.build(teammate_id: @teammate_id)
      end
    end

    def existing_observee
      if @observation.persisted?
        @observation.observees.find_by(teammate_id: @teammate_id)
      else
        @observation.observees.detect { |o| o.teammate_id.to_s == @teammate_id.to_s }
      end
    end
  end
end
