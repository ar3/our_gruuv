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
      teammate = observee.teammate || CompanyTeammate.find_by(id: @teammate_id)
      return observee unless teammate

      # Add active assignments with given energy as 'na' ratings
      add_active_assignments_as_ratings(teammate)

      # Add ability ratings for abilities from required/active assignments and position direct milestones
      add_relevant_abilities_as_ratings(teammate)

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

    def add_relevant_abilities_as_ratings(teammate)
      relevant_ability_ids_for_observee(teammate).each do |ability_id|
        next if rating_exists?('Ability', ability_id)

        add_rating('Ability', ability_id)
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

    def add_active_assignments_as_ratings(teammate)
      # Find all active assignment tenures with given energy for this teammate
      active_tenures = teammate.assignment_tenures
                                .active_and_given_energy
                                .joins(:assignment)
                                .where(assignments: { company: @observation.company })
                                .includes(:assignment)

      active_tenures.each do |tenure|
        next if rating_exists?('Assignment', tenure.assignment_id)

        add_rating('Assignment', tenure.assignment_id, rateable: tenure.assignment)
      end
    end

    def rating_exists?(rateable_type, rateable_id)
      if @observation.persisted?
        @observation.observation_ratings.exists?(
          rateable_type: rateable_type,
          rateable_id: rateable_id
        )
      else
        @observation.observation_ratings.any? do |rating|
          rating.rateable_type == rateable_type && rating.rateable_id.to_s == rateable_id.to_s
        end
      end
    end

    def add_rating(rateable_type, rateable_id, rateable: nil)
      if @observation.persisted?
        @observation.observation_ratings.create!(
          rateable_type: rateable_type,
          rateable_id: rateable_id,
          rating: 'na'
        )
      else
        rating = @observation.observation_ratings.build(
          rateable_type: rateable_type,
          rateable_id: rateable_id,
          rating: 'na'
        )
        rating.rateable = rateable || rateable_type.constantize.find_by(id: rateable_id)
        rating
      end
    end
  end
end
