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

      # Add ability ratings for abilities from required/active assignments and position direct milestones
      add_relevant_abilities_as_ratings(observee.teammate)

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

    def add_relevant_abilities_as_ratings(teammate)
      ability_ids = relevant_ability_ids_for_observee(teammate)
      ability_ids.each do |ability_id|
        next if rating_exists_for_ability?(ability_id)

        @observation.observation_ratings.create!(
          rateable_type: 'Ability',
          rateable_id: ability_id,
          rating: 'na'
        )
      end
    end

    def relevant_ability_ids_for_observee(teammate)
      ids = Set.new
      company = @observation.company
      org_ids = company.self_and_descendants.pluck(:id)

      # From position's required assignments and direct milestone requirements
      active_tenure = teammate.active_employment_tenure
      if active_tenure&.position
        position = active_tenure.position
        # Required assignments' abilities (same org as position)
        position.required_assignments
          .joins(assignment: { assignment_abilities: :ability })
          .where(abilities: { company_id: org_ids })
          .pluck('assignment_abilities.ability_id')
          .each { |id| ids.add(id) }
        # Position direct milestone requirements
        position.position_abilities
          .joins(:ability)
          .where(abilities: { company_id: org_ids })
          .pluck(:ability_id)
          .each { |id| ids.add(id) }
      end

      # From teammate's active assignment tenures (with given energy)
      teammate.assignment_tenures
        .active_and_given_energy
        .joins(assignment: :assignment_abilities)
        .where(assignments: { company_id: org_ids })
        .pluck('assignment_abilities.ability_id')
        .each { |id| ids.add(id) }

      ids.to_a
    end

    def rating_exists_for_ability?(ability_id)
      @observation.observation_ratings.exists?(
        rateable_type: 'Ability',
        rateable_id: ability_id
      )
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

