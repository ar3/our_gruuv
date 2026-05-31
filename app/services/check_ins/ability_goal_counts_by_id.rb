# frozen_string_literal: true

module CheckIns
  class AbilityGoalCountsById
    EMPTY_COUNTS = { draft: 0, active: 0, completed: 0 }.freeze

    def self.call(teammate:, ability_ids:)
      new(teammate: teammate, ability_ids: ability_ids).call
    end

    def initialize(teammate:, ability_ids:)
      @teammate = teammate
      @ability_ids = Array(ability_ids).compact.uniq
    end

    def call
      return {} if @teammate.blank? || @ability_ids.empty?

      counts = @ability_ids.index_with { EMPTY_COUNTS.dup }

      GoalAssociation
        .joins(:goal)
        .where(associable_type: "Ability", associable_id: @ability_ids)
        .where(goals: { owner_type: "CompanyTeammate", owner_id: @teammate.id, deleted_at: nil })
        .pluck(:associable_id, "goals.started_at", "goals.completed_at")
        .each do |ability_id, started_at, completed_at|
          bucket = counts[ability_id]
          next unless bucket

          if completed_at.present?
            bucket[:completed] += 1
          elsif started_at.present?
            bucket[:active] += 1
          else
            bucket[:draft] += 1
          end
        end

      counts
    end
  end
end
