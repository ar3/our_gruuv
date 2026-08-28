# frozen_string_literal: true

module AssignmentSurveys
  # Ensures in-progress response rows exist for eligible assignments.
  class ResponseWorkspace
    def initialize(organization:, teammate:, assignment_ids: nil)
      @organization = organization
      @teammate = teammate
      @assignment_ids = Array(assignment_ids).presence
    end

    def self.assignment_rows_for(organization:, teammate:)
      new(organization: organization, teammate: teammate).assignment_rows
    end

    def call
      rows = filtered_assignment_rows
      return AssignmentSurveyResponse.none if rows.empty?

      rows.map do |assignment, source|
        find_or_create_in_progress!(assignment, source)
      end
    end

    def in_progress_responses
      scope = teammate.assignment_survey_responses
        .in_progress
        .where(organization: organization)
        .includes(:assignment)
        .order(:snapshot_title)

      return scope unless assignment_ids.present?

      scope.where(assignment_id: assignment_ids.map(&:to_i))
    end

    def assignment_rows
      active_ids = teammate.assignment_tenures
        .active
        .joins(:assignment)
        .where(assignments: { company: organization })
        .pluck(:assignment_id)
        .to_set
      required_ids = required_assignment_ids.to_set
      ids = active_ids | required_ids

      Assignment.unarchived.where(company: organization, id: ids).includes(:assignment_outcomes).ordered.map do |assignment|
        source =
          if active_ids.include?(assignment.id) && required_ids.include?(assignment.id)
            "active_and_required"
          elsif active_ids.include?(assignment.id)
            "active"
          else
            "required"
          end
        [ assignment, source ]
      end
    end

    private

    attr_reader :organization, :teammate, :assignment_ids

    def filtered_assignment_rows
      rows = assignment_rows
      return rows if assignment_ids.blank?

      id_set = assignment_ids.map(&:to_i).to_set
      rows.select { |assignment, _source| id_set.include?(assignment.id) }
    end

    def find_or_create_in_progress!(assignment, source)
      existing = teammate.assignment_survey_responses.in_progress.find_by(
        organization: organization,
        assignment: assignment
      )
      return existing if existing

      teammate.assignment_survey_responses.create!(
        organization: organization,
        assignment: assignment,
        assignment_source: source,
        snapshot_title: assignment.title,
        snapshot_tagline: assignment.tagline,
        snapshot_required_activities: assignment.required_activities,
        snapshot_outcomes: assignment.outcomes.map do |outcome|
          { "type" => outcome.outcome_type, "description" => outcome.description }
        end
      )
    rescue ActiveRecord::RecordNotUnique
      teammate.assignment_survey_responses.in_progress.find_by!(
        organization: organization,
        assignment: assignment
      )
    end

    def required_assignment_ids
      position = teammate.active_employment_tenure&.position
      return [] unless position

      position.required_assignments.pluck(:assignment_id)
    end
  end
end
