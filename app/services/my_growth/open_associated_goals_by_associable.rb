# frozen_string_literal: true

module MyGrowth
  # Open (incomplete, unarchived) goals owned by a teammate and associated to Assignments or Abilities,
  # plus each goal's latest confidence check-in for catalog-card footers.
  class OpenAssociatedGoalsByAssociable
    def self.call(teammate:, associable_type:, associable_ids:)
      new(teammate: teammate, associable_type: associable_type, associable_ids: associable_ids).call
    end

    def initialize(teammate:, associable_type:, associable_ids:)
      @teammate = teammate
      @associable_type = associable_type
      @associable_ids = Array(associable_ids).compact.uniq
    end

    def call
      return {} if @teammate.blank? || @associable_ids.empty?

      rows = GoalAssociation
        .joins(:goal)
        .where(associable_type: @associable_type, associable_id: @associable_ids)
        .where(goals: { owner_type: "CompanyTeammate", owner_id: @teammate.id })
        .merge(Goal.incomplete_unarchived)
        .pluck("goal_associations.associable_id", "goals.id", "goals.title")

      goals_by_associable = Hash.new { |h, k| h[k] = [] }
      rows.each do |associable_id, goal_id, title|
        goals_by_associable[associable_id] << { id: goal_id, title: title }
      end

      check_ins_by_goal_id = latest_check_ins_by_goal_id(goals_by_associable.values.flatten.map { |g| g[:id] })

      @associable_ids.index_with do |aid|
        open_goals = goals_by_associable[aid]
          .sort_by { |g| [g[:title].to_s.downcase, g[:id]] }
          .map do |g|
            check_in = check_ins_by_goal_id[g[:id]]
            {
              title: g[:title],
              confidence_percentage: check_in&.confidence_percentage,
              confidence_saved_at: check_in&.created_at
            }
          end

        {
          open_associated_goals_count: open_goals.size,
          open_associated_goals: open_goals
        }
      end
    end

    private

    def latest_check_ins_by_goal_id(goal_ids)
      return {} if goal_ids.empty?

      GoalCheckIn
        .where(goal_id: goal_ids)
        .recent
        .group_by(&:goal_id)
        .transform_values(&:first)
    end
  end
end
