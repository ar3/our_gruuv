# frozen_string_literal: true

module Goals
  # Goals linked to an Assignment/Ability/Aspiration that may be shown on a page,
  # filtered by viewer privacy and (on teammate lens pages) subject teammate ownership.
  class VisibleAssociableGoalsForDisplay
    def initialize(associable:, viewer:, goals_scope:, subject_teammate: nil)
      @associable = associable
      @viewer = viewer
      @goals_scope = goals_scope
      @subject_teammate = subject_teammate
    end

    def call
      goals = scoped_associated_goals
      goals = filter_viewable(goals)
      goals = filter_for_subject_teammate(goals)
      goals = reject_archived(goals)
      goal_ids = goals.map(&:id)

      hierarchy = LinkedGoalsHierarchyLoader.call(goal_ids: goal_ids)
      visible_linked = filter_viewable_hash(hierarchy[:linked_goals])
      visible_check_ins = hierarchy[:linked_goal_check_ins].slice(*visible_linked.keys)

      {
        goals: goals,
        linked_goals: visible_linked,
        linked_goal_check_ins: visible_check_ins,
        goal_association_by_goal_id: goal_associations_by_goal_id(goals)
      }
    end

    private

    attr_reader :associable, :viewer, :goals_scope, :subject_teammate

    def scoped_associated_goals
      associated_ids = associable.goals.pluck(:id)
      return [] if associated_ids.empty?

      goals_scope.where(id: associated_ids).to_a
    end

    def filter_viewable(goals)
      goals.select { |goal| goal.can_be_viewed_by?(viewer) }
    end

    def filter_for_subject_teammate(goals)
      return goals unless subject_teammate

      goals.select { |goal| goal.owner_type == "CompanyTeammate" && goal.owner_id == subject_teammate.id }
    end

    def reject_archived(goals)
      goals.reject { |goal| goal.deleted_at.present? }
    end

    def filter_viewable_hash(linked_goals)
      linked_goals.select { |_, goal| goal.can_be_viewed_by?(viewer) }
    end

    def goal_associations_by_goal_id(goals)
      visible_ids = goals.map(&:id).to_set
      associable.goal_associations.includes(:goal).select { |ga| visible_ids.include?(ga.goal_id) }.index_by(&:goal_id)
    end
  end
end
