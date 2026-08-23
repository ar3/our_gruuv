# frozen_string_literal: true

module CheckIns
  # Latest finalized check-ins (per position / assignment / aspiration) that still
  # need employee acknowledgement. Used by the Phase 1 acknowledge page.
  class AcknowledgementQueue
    Result = Struct.new(
      :position_check_in,
      :assignment_check_ins,
      :aspiration_check_ins,
      keyword_init: true
    )

    def self.for(teammate:)
      new(teammate: teammate).call
    end

    def initialize(teammate:)
      @teammate = teammate
    end

    def call
      Result.new(
        position_check_in: latest_position_awaiting,
        assignment_check_ins: latest_assignments_awaiting,
        aspiration_check_ins: latest_aspirations_awaiting
      )
    end

    private

    def latest_position_awaiting
      check_in = PositionCheckIn
        .includes(:finalized_by_teammate, :manager_completed_by_teammate, employment_tenure: :position)
        .where(company_teammate: @teammate)
        .closed
        .order(official_check_in_completed_at: :desc)
        .first
      check_in if check_in&.awaiting_employee_acknowledgement?
    end

    def latest_assignments_awaiting
      scope = AssignmentCheckIn
        .where(company_teammate: @teammate)
        .includes(:assignment, :finalized_by_teammate, :manager_completed_by_teammate)
      AssignmentCheckIn
        .latest_finalized_index_by(scope, :assignment_id)
        .values
        .select(&:awaiting_employee_acknowledgement?)
        .sort_by { |ci| ci.assignment&.title.to_s.downcase }
    end

    def latest_aspirations_awaiting
      scope = AspirationCheckIn
        .where(company_teammate: @teammate)
        .includes(:aspiration, :finalized_by_teammate, :manager_completed_by_teammate)
      AspirationCheckIn
        .latest_finalized_index_by(scope, :aspiration_id)
        .values
        .select(&:awaiting_employee_acknowledgement?)
        .sort_by { |ci| ci.aspiration&.name.to_s.downcase }
    end
  end
end
