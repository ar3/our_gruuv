module AssignmentSurveys
  class DraftBuilder
    def initialize(organization:, teammate:)
      @organization = organization
      @teammate = teammate
    end

    def call
      existing_draft = teammate.assignment_survey_submissions.draft.first
      return existing_draft if existing_draft

      rows = assignment_rows
      return nil if rows.empty?

      AssignmentSurveySubmission.transaction do
        submission = teammate.assignment_survey_submissions.create!(organization: organization)
        rows.each do |assignment, source|
          submission.responses.create!(
            assignment: assignment,
            assignment_source: source,
            snapshot_title: assignment.title,
            snapshot_tagline: assignment.tagline,
            snapshot_required_activities: assignment.required_activities,
            snapshot_outcomes: assignment.outcomes.map do |outcome|
              { "type" => outcome.outcome_type, "description" => outcome.description }
            end
          )
        end
        submission
      end
    rescue ActiveRecord::RecordNotUnique
      teammate.assignment_survey_submissions.draft.first!
    end

    private

    attr_reader :organization, :teammate

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

    def required_assignment_ids
      position = teammate.active_employment_tenure&.position
      return [] unless position

      position.required_assignments.pluck(:assignment_id)
    end
  end
end
