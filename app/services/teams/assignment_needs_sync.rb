# frozen_string_literal: true

module Teams
  class AssignmentNeedsSync
    def initialize(team:, need_types_by_assignment_id:)
      @team = team
      @need_types_by_assignment_id = need_types_by_assignment_id
    end

    def call
      assignment_ids = @team.company.assignments.unarchived.where(id: @need_types_by_assignment_id.keys).pluck(:id)
      valid_need_types = @need_types_by_assignment_id.slice(*assignment_ids)

      ActiveRecord::Base.transaction do
        remove_unlisted_needs(valid_need_types.keys)
        upsert_needs(valid_need_types)
        prune_primary_outcomes_for_removed_needs(valid_need_types.keys)
      end
    end

    private

    def remove_unlisted_needs(assignment_ids_to_keep)
      scope = @team.team_assignment_needs
      if assignment_ids_to_keep.any?
        scope.where.not(assignment_id: assignment_ids_to_keep).destroy_all
      else
        scope.destroy_all
      end
    end

    def upsert_needs(valid_need_types)
      valid_need_types.each do |assignment_id, need_type|
        next unless TeamAssignmentNeed::NEED_TYPES.include?(need_type)

        need = @team.team_assignment_needs.find_or_initialize_by(assignment_id: assignment_id)
        need.need_type = need_type
        need.save!
      end
    end

    def prune_primary_outcomes_for_removed_needs(assignment_ids_to_keep)
      if assignment_ids_to_keep.empty?
        @team.team_primary_outcomes.destroy_all
        return
      end

      @team.team_primary_outcomes
        .joins(:assignment_outcome)
        .where.not(assignment_outcomes: { assignment_id: assignment_ids_to_keep })
        .destroy_all
    end
  end
end
