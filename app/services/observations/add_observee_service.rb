module Observations
  class AddObserveeService
    def initialize(observation:, teammate_id:)
      @observation = observation
      @teammate_id = teammate_id
    end

    def call
      # Ensure observation is loaded with company
      @observation.reload if @observation.persisted?
      
      # Check if observee already exists
      observee = existing_observee if observee_exists?
      
      # Create the observee if it doesn't exist
      observee ||= @observation.observees.create!(teammate_id: @teammate_id)

      # Add active assignments with given energy as 'na' ratings
      add_active_assignments_as_ratings(observee.teammate)

      observee
    end

    private

    attr_reader :observation, :teammate_id

    def observee_exists?
      @observation.observees.exists?(teammate_id: @teammate_id)
    end

    def existing_observee
      @observation.observees.find_by(teammate_id: @teammate_id)
    end

    def add_active_assignments_as_ratings(teammate)
      # Find all active assignment tenures with given energy for this teammate
      active_tenures = teammate.assignment_tenures
                                .active_and_given_energy
                                .joins(:assignment)
                                .where(assignments: { company: @observation.company })
                                .includes(:assignment)

      active_tenures.each do |tenure|
        # Only create rating if one doesn't already exist for this assignment
        next if rating_exists_for_assignment?(tenure.assignment)

        @observation.observation_ratings.create!(
          rateable_type: 'Assignment',
          rateable_id: tenure.assignment_id,
          rating: 'na'
        )
      end
    end

    def rating_exists_for_assignment?(assignment)
      @observation.observation_ratings.exists?(
        rateable_type: 'Assignment',
        rateable_id: assignment.id
      )
    end
  end
end

