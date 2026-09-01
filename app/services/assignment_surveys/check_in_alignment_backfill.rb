# frozen_string_literal: true

module AssignmentSurveys
  # Idempotent backfill: employee-completed assignment check-ins with personal
  # alignment become submitted survey responses (alignment-only history).
  #
  # Console:
  #   AssignmentSurveys::CheckInAlignmentBackfill.call(dry_run: true)
  #   AssignmentSurveys::CheckInAlignmentBackfill.call(dry_run: false)
  #
  class CheckInAlignmentBackfill
    Result = Struct.new(:dry_run, :scanned, :created, :skipped, :errors, keyword_init: true)

    def self.call(dry_run: true, organization: nil)
      new(dry_run: dry_run, organization: organization).call
    end

    def initialize(dry_run:, organization: nil)
      @dry_run = dry_run
      @organization = organization
    end

    def call
      stats = { scanned: 0, created: 0, skipped: 0, errors: [] }

      eligible_scope.find_each do |check_in|
        stats[:scanned] += 1

        begin
          if AssignmentSurveyResponse.exists?(source_assignment_check_in_id: check_in.id)
            stats[:skipped] += 1
            next
          end

          if @dry_run
            stats[:created] += 1
            next
          end

          create_response!(check_in)
          stats[:created] += 1
        rescue ActiveRecord::RecordNotUnique
          stats[:skipped] += 1
        rescue StandardError => e
          stats[:errors] << { check_in_id: check_in.id, message: e.message }
        end
      end

      Result.new(
        dry_run: @dry_run,
        scanned: stats[:scanned],
        created: stats[:created],
        skipped: stats[:skipped],
        errors: stats[:errors]
      )
    end

    private

    def eligible_scope
      scope = AssignmentCheckIn
        .where.not(employee_personal_alignment: nil)
        .where.not(employee_completed_at: nil)
        .includes(:assignment, company_teammate: :organization)

      return scope if @organization.blank?

      scope.joins(:assignment).where(assignments: { company_id: @organization.id })
    end

    def create_response!(check_in)
      assignment = check_in.assignment
      teammate = check_in.company_teammate
      organization = assignment.company

      AssignmentSurveyResponse.create!(
        company_teammate: teammate,
        organization: organization,
        assignment: assignment,
        assignment_source: "active",
        snapshot_title: assignment.title,
        snapshot_tagline: assignment.tagline,
        snapshot_required_activities: assignment.required_activities,
        snapshot_outcomes: snapshot_outcomes_for(assignment),
        personal_alignment: check_in.employee_personal_alignment,
        submitted_at: check_in.employee_completed_at,
        source_assignment_check_in_id: check_in.id
      )
    end

    def snapshot_outcomes_for(assignment)
      assignment.outcomes.map do |outcome|
        { "type" => outcome.outcome_type, "description" => outcome.description }
      end
    end
  end
end
