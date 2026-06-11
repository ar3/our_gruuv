# frozen_string_literal: true

module Goals
  # Active goals owned by a teammate, plus draft parent goals owned by the same teammate
  # (for hierarchy context). When a manager views, excludes goals they cannot see (private).
  class BulkCheckInGoalsScopeQuery
    def initialize(teammate:, organization:, viewing_teammate:)
      @teammate = teammate
      @organization = organization
      @viewing_teammate = viewing_teammate
    end

    def call
      active_goals = teammate_owned_scope.active.to_a
      draft_parents = draft_parent_goals_for(active_goals)
      goals = (active_goals + draft_parents).uniq(&:id)

      if manager_viewing?
        goals.select! { |goal| goal.can_be_viewed_by?(viewing_teammate.person) }
      end

      goals
    end

    private

    attr_reader :teammate, :organization, :viewing_teammate

    def company
      @company ||= organization.root_company || organization
    end

    def teammate_owned_scope
      Goal.where(company: company, owner: teammate)
          .where(completed_at: nil, deleted_at: nil)
    end

    def teammate_goal_ids
      @teammate_goal_ids ||= teammate_owned_scope.pluck(:id).to_set
    end

    def manager_viewing?
      viewing_teammate.id != teammate.id
    end

    def draft_parent_goals_for(active_goals)
      return [] if active_goals.empty?

      active_ids = active_goals.map(&:id).to_set
      draft_parent_ids = Set.new
      queue = active_ids.to_a

      while queue.any?
        child_id = queue.pop
        parent_ids = GoalLink.where(child_id: child_id, parent_id: teammate_goal_ids.to_a).pluck(:parent_id)

        parent_ids.each do |parent_id|
          next if active_ids.include?(parent_id) || draft_parent_ids.include?(parent_id)

          parent = teammate_owned_scope.find_by(id: parent_id)
          next unless parent&.started_at.nil?

          draft_parent_ids.add(parent_id)
          queue << parent_id
        end
      end

      draft_parent_ids.empty? ? [] : Goal.where(id: draft_parent_ids.to_a).to_a
    end
  end
end
