# frozen_string_literal: true

module CheckIns
  # Acknowledges every check-in in the payload that is Agree or Disagree.
  # Leave Unacknowledged entries are skipped. Continues on per-item failures.
  class BulkAcknowledgeCheckInsService
    def self.call(teammate:, acknowledgements:, request_info: {})
      new(teammate: teammate, acknowledgements: acknowledgements, request_info: request_info).call
    end

    def initialize(teammate:, acknowledgements:, request_info: {})
      @teammate = teammate
      @acknowledgements = acknowledgements || {}
      @request_info = request_info || {}
    end

    def call
      saved = 0
      skipped = 0
      errors = []

      each_entry do |check_in_type, check_in_id, acknowledgement, notes|
        if acknowledgement.blank? || acknowledgement == "leave_unacknowledged"
          skipped += 1
          next
        end

        result = AcknowledgeCheckInService.call(
          teammate: @teammate,
          check_in_type: check_in_type,
          check_in_id: check_in_id,
          acknowledgement: acknowledgement,
          notes: notes,
          request_info: @request_info
        )

        if result.ok?
          saved += 1
        else
          errors << result.error
        end
      end

      Result.ok(saved: saved, skipped: skipped, errors: errors)
    end

    private

    def each_entry
      @acknowledgements.each do |check_in_type, by_id|
        next unless by_id.respond_to?(:each)

        by_id.each do |check_in_id, attrs|
          attrs = attrs.to_unsafe_h if attrs.respond_to?(:to_unsafe_h)
          attrs = attrs.with_indifferent_access if attrs.respond_to?(:with_indifferent_access)
          yield(
            check_in_type.to_s,
            check_in_id,
            attrs[:employee_acknowledgement].to_s,
            attrs[:employee_acknowledgement_notes]
          )
        end
      end
    end
  end
end
