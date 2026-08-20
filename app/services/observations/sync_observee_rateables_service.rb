module Observations
  # Keeps Assignment/Ability ratings representative of the current observees:
  # intersection of each observee's relevant abilities and active given-energy
  # assignments. Preserves already-scored ratings; prunes only unscored (na) rows
  # that fall outside the intersection. Also ensures company aspirational values
  # are present (add-if-missing only; never removes Aspiration ratings).
  class SyncObserveeRateablesService
    RATEABLE_TYPES = %w[Assignment Ability].freeze

    def initialize(observation:)
      @observation = observation
    end

    def call
      teammates = current_observee_teammates
      assignment_ids, ability_ids = intersection_rateable_ids(teammates)

      sync_type('Assignment', assignment_ids)
      sync_type('Ability', ability_ids)
      EnsureCompanyAspirationsService.new(observation: @observation).call

      @observation
    end

    private

    attr_reader :observation

    def current_observee_teammates
      observees = if @observation.persisted?
                    @observation.observees.includes(:company_teammate).to_a
                  else
                    @observation.observees.select { |o| o.teammate_id.present? }
                  end

      observees.filter_map do |observee|
        observee.company_teammate || CompanyTeammate.find_by(id: observee.teammate_id)
      end
    end

    def intersection_rateable_ids(teammates)
      return [[], []] if teammates.empty?

      assignment_sets = teammates.map { |tm| active_assignment_ids_for(tm).to_set }
      ability_sets = teammates.map { |tm| relevant_ability_ids_for(tm).to_set }

      [
        assignment_sets.reduce(&:intersection).to_a,
        ability_sets.reduce(&:intersection).to_a
      ]
    end

    def active_assignment_ids_for(teammate)
      teammate.assignment_tenures
              .active_and_given_energy
              .joins(:assignment)
              .where(assignments: { company: @observation.company })
              .pluck(:assignment_id)
    end

    def relevant_ability_ids_for(teammate)
      ids = Set.new
      company = @observation.company
      org_ids = company.self_and_descendants.pluck(:id)

      active_tenure = teammate.active_employment_tenure
      if active_tenure&.position
        position = active_tenure.position
        position.required_assignments
          .joins(assignment: { assignment_abilities: :ability })
          .where(abilities: { company_id: org_ids })
          .pluck('assignment_abilities.ability_id')
          .each { |id| ids.add(id) }
        position.position_abilities
          .joins(:ability)
          .where(abilities: { company_id: org_ids })
          .pluck(:ability_id)
          .each { |id| ids.add(id) }
      end

      teammate.assignment_tenures
        .active_and_given_energy
        .joins(assignment: :assignment_abilities)
        .where(assignments: { company_id: org_ids })
        .pluck('assignment_abilities.ability_id')
        .each { |id| ids.add(id) }

      ids
    end

    def sync_type(rateable_type, keep_ids)
      keep_ids = keep_ids.map(&:to_i).uniq
      keep_set = keep_ids.to_set

      existing = ratings_for_type(rateable_type)
      existing.each do |rating|
        next if keep_set.include?(rating.rateable_id.to_i)
        next unless unscored?(rating)

        destroy_rating(rating)
      end

      keep_ids.each do |rateable_id|
        next if rating_exists?(rateable_type, rateable_id)

        add_rating(rateable_type, rateable_id)
      end
    end

    def ratings_for_type(rateable_type)
      if @observation.persisted?
        @observation.observation_ratings.where(rateable_type: rateable_type).to_a
      else
        @observation.observation_ratings.select { |r| r.rateable_type == rateable_type }
      end
    end

    def unscored?(rating)
      rating.rating.to_s == 'na'
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

    def destroy_rating(rating)
      if @observation.persisted? && rating.persisted?
        rating.destroy!
      else
        @observation.observation_ratings.delete(rating)
      end
    end

    def add_rating(rateable_type, rateable_id)
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
        rating.rateable = rateable_type.constantize.find_by(id: rateable_id)
        rating
      end
    end
  end
end
