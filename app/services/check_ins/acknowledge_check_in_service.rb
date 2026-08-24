# frozen_string_literal: true

module CheckIns
  # Persists employee acknowledgement (agree / disagree + optional notes) on a
  # single finalized check-in. Acknowledgement is immutable once set.
  class AcknowledgeCheckInService
    CHECK_IN_TYPES = {
      "position" => PositionCheckIn,
      "assignment" => AssignmentCheckIn,
      "aspiration" => AspirationCheckIn
    }.freeze

    def self.call(teammate:, check_in_type:, check_in_id:, acknowledgement:, notes: nil, request_info: {})
      new(
        teammate: teammate,
        check_in_type: check_in_type,
        check_in_id: check_in_id,
        acknowledgement: acknowledgement,
        notes: notes,
        request_info: request_info
      ).call
    end

    def initialize(teammate:, check_in_type:, check_in_id:, acknowledgement:, notes: nil, request_info: {})
      @teammate = teammate
      @check_in_type = check_in_type.to_s
      @check_in_id = check_in_id
      @acknowledgement = acknowledgement.to_s
      @notes = notes
      @request_info = request_info || {}
    end

    def call
      klass = CHECK_IN_TYPES[@check_in_type]
      return Result.err("Invalid check-in type.") unless klass

      check_in = klass.find_by(id: @check_in_id, teammate_id: @teammate.id)
      return Result.err("Check-in not found.") unless check_in
      return Result.err("Only finalized check-ins can be acknowledged.") unless check_in.closed?
      return Result.err("This check-in has already been acknowledged.") if check_in.employee_acknowledged?
      return Result.err("Only the latest finalized check-in for this item can be acknowledged.") unless latest_for_item?(check_in)

      unless %w[agree disagree].include?(@acknowledgement)
        return Result.err("Choose Acknowledge and Agree or Acknowledge and Disagree.")
      end

      check_in.acknowledge_as_employee!(
        acknowledgement: @acknowledgement,
        notes: @notes,
        request_info: @request_info
      )
      Result.ok(check_in)
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages.to_sentence.presence || "Could not save acknowledgement.")
    end

    private

    def latest_for_item?(check_in)
      case check_in
      when PositionCheckIn
        PositionCheckIn.latest_finalized_for(@teammate)&.id == check_in.id
      when AssignmentCheckIn
        latest = AssignmentCheckIn
          .where(company_teammate: @teammate, assignment_id: check_in.assignment_id)
          .closed
          .order(official_check_in_completed_at: :desc)
          .first
        latest&.id == check_in.id
      when AspirationCheckIn
        latest = AspirationCheckIn
          .where(company_teammate: @teammate, aspiration_id: check_in.aspiration_id)
          .closed
          .order(official_check_in_completed_at: :desc)
          .first
        latest&.id == check_in.id
      else
        false
      end
    end
  end
end
