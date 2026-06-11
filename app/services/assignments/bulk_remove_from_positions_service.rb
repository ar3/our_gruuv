module Assignments
  class BulkRemoveFromPositionsService
    def self.call(assignment:)
      new(assignment: assignment).call
    end

    def initialize(assignment:)
      @assignment = assignment
    end

    def call
      count = assignment.position_assignments.count
      return Result.err('No position assignments to remove.') if count.zero?

      ApplicationRecord.transaction do
        assignment.position_assignments.destroy_all
      end

      Result.ok(count: count)
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages.join(', '))
    rescue => e
      Result.err("Failed to remove position assignments: #{e.message}")
    end

    private

    attr_reader :assignment
  end
end
