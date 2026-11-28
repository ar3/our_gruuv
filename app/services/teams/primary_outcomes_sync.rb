# frozen_string_literal: true

module Teams
  class PrimaryOutcomesSync
    def initialize(team:, assignment_outcome_ids:)
      @team = team
      @assignment_outcome_ids = Array(assignment_outcome_ids).map(&:to_i).uniq
    end

    def call
      eligible_ids = eligible_outcome_ids & @assignment_outcome_ids

      ActiveRecord::Base.transaction do
        remove_unlisted(eligible_ids)
        create_missing(eligible_ids)
      end
    end

    private

    def eligible_outcome_ids
      needed_assignment_ids = @team.team_assignment_needs.pluck(:assignment_id)
      return [] if needed_assignment_ids.empty?

      AssignmentOutcome.where(assignment_id: needed_assignment_ids).pluck(:id)
    end

    def remove_unlisted(ids_to_keep)
      scope = @team.team_primary_outcomes
      if ids_to_keep.any?
        scope.where.not(assignment_outcome_id: ids_to_keep).destroy_all
      else
        scope.destroy_all
      end
    end

    def create_missing(ids_to_keep)
      existing = @team.team_primary_outcomes.pluck(:assignment_outcome_id)
      (ids_to_keep - existing).each do |outcome_id|
        @team.team_primary_outcomes.create!(assignment_outcome_id: outcome_id)
      end
    end
  end
end
