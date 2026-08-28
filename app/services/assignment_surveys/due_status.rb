# frozen_string_literal: true

module AssignmentSurveys
  # Per-assignment due/early signal for employee survey feedback.
  class DueStatus
    Result = Struct.new(
      :assignment,
      :latest_response,
      :latest_submitted_at,
      :due?,
      :early?,
      :never_submitted?,
      :reason,
      keyword_init: true
    )

    def self.for(teammate:, assignment:)
      new(teammate: teammate, assignments: [ assignment ]).call.first
    end

    def self.for_teammate(teammate:, assignments:)
      new(teammate: teammate, assignments: assignments).call
    end

    def initialize(teammate:, assignments:)
      @teammate = teammate
      @assignments = Array(assignments)
    end

    def call
      assignments.map { |assignment| build_result(assignment) }
    end

    private

    attr_reader :teammate, :assignments

    def build_result(assignment)
      latest = latest_by_assignment[assignment.id]
      submitted_at = latest&.submitted_at
      never = latest.blank?

      if never
        return Result.new(
          assignment: assignment,
          latest_response: nil,
          latest_submitted_at: nil,
          due?: true,
          early?: false,
          never_submitted?: true,
          reason: :never_submitted
        )
      end

      if check_in_since?(assignment, submitted_at)
        return Result.new(
          assignment: assignment,
          latest_response: latest,
          latest_submitted_at: submitted_at,
          due?: true,
          early?: false,
          never_submitted?: false,
          reason: :check_in_since
        )
      end

      if assignment_changed_since?(assignment, submitted_at)
        return Result.new(
          assignment: assignment,
          latest_response: latest,
          latest_submitted_at: submitted_at,
          due?: true,
          early?: false,
          never_submitted?: false,
          reason: :assignment_changed
        )
      end

      Result.new(
        assignment: assignment,
        latest_response: latest,
        latest_submitted_at: submitted_at,
        due?: false,
        early?: true,
        never_submitted?: false,
        reason: :fresh
      )
    end

    def latest_by_assignment
      @latest_by_assignment ||= begin
        return {} if assignments.empty?

        rows = teammate.assignment_survey_responses
          .submitted
          .where(assignment_id: assignments.map(&:id))
          .latest_submitted_first

        rows.each_with_object({}) do |response, memo|
          memo[response.assignment_id] ||= response
        end
      end
    end

    def check_in_since?(assignment, submitted_at)
      AssignmentCheckIn
        .where(assignment_id: assignment.id, teammate_id: teammate.id)
        .where.not(employee_completed_at: nil)
        .where("employee_completed_at > ?", submitted_at)
        .exists?
    end

    def assignment_changed_since?(assignment, submitted_at)
      assignment.updated_at.present? && assignment.updated_at > submitted_at
    end
  end
end
