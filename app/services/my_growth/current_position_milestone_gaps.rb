# frozen_string_literal: true

module MyGrowth
  # Required ability milestones for the teammate's current position, with coverage
  # status for Grow by Goals → Missing Milestone goals.
  class CurrentPositionMilestoneGaps
    Row = Data.define(
      :ability,
      :required_level,
      :earned_level,
      :met,
      :has_active_goal,
      :active_goal_count,
      :draft_goal_count
    )

    Result = Data.define(:position, :rows)

    def self.call(teammate:)
      new(teammate: teammate).call
    end

    def initialize(teammate:)
      @teammate = teammate
    end

    def call
      position = teammate.active_employment_tenure&.position
      return Result.new(position: position, rows: []) if position.blank?

      requirements = MyGrowthAbilityMilestoneRows.structured_requirements_by_ability_id(position)
      return Result.new(position: position, rows: []) if requirements.empty?

      ability_ids = requirements.keys
      abilities = Ability.where(id: ability_ids).index_by(&:id)
      earned = TeammateMilestone
        .where(company_teammate: teammate, ability_id: ability_ids)
        .group(:ability_id)
        .maximum(:milestone_level)
      goal_counts = goal_counts_for(ability_ids)

      rows = ability_ids.filter_map do |ability_id|
        ability = abilities[ability_id]
        next unless ability

        required_level = requirements[ability_id][:minimum_milestone_level].to_i
        earned_level = earned[ability_id].to_i
        counts = goal_counts[ability_id] || { active: 0, draft: 0 }

        Row.new(
          ability: ability,
          required_level: required_level,
          earned_level: earned_level,
          met: earned_level >= required_level,
          has_active_goal: counts[:active].positive?,
          active_goal_count: counts[:active],
          draft_goal_count: counts[:draft]
        )
      end.sort_by { |row| [row.met ? 1 : 0, row.has_active_goal ? 1 : 0, row.ability.name.to_s.downcase] }

      Result.new(position: position, rows: rows)
    end

    private

    attr_reader :teammate

    def goal_counts_for(ability_ids)
      GoalAssociation
        .joins(:goal)
        .where(
          associable_type: "Ability",
          associable_id: ability_ids,
          goals: {
            owner_type: "CompanyTeammate",
            owner_id: teammate.id,
            completed_at: nil,
            deleted_at: nil
          }
        )
        .group("goal_associations.associable_id")
        .pluck(
          Arel.sql("goal_associations.associable_id"),
          Arel.sql("COUNT(*) FILTER (WHERE goals.started_at IS NOT NULL)"),
          Arel.sql("COUNT(*) FILTER (WHERE goals.started_at IS NULL)")
        )
        .each_with_object({}) do |(id, active, draft), memo|
          memo[id] = { active: active.to_i, draft: draft.to_i }
        end
    end
  end
end
