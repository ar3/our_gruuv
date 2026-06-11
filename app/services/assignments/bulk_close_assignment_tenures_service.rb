module Assignments
  class BulkCloseAssignmentTenuresService
    def self.call(assignment:, creator_teammate:, request_info: {})
      new(assignment: assignment, creator_teammate: creator_teammate, request_info: request_info).call
    end

    def initialize(assignment:, creator_teammate:, request_info: {})
      @assignment = assignment
      @creator_teammate = creator_teammate
      @request_info = request_info
    end

    def call
      active_tenures = assignment.assignment_tenures.active.includes(company_teammate: :person).to_a
      return Result.err('No active assignment tenures to close.') if active_tenures.empty?

      closed_count = 0
      reason = bulk_close_reason

      ApplicationRecord.transaction do
        active_tenures.each do |tenure|
          tenure.update!(
            ended_at: Date.current,
            anticipated_energy_percentage: 0
          )

          snapshot = MaapSnapshot.build_for_employee(
            employee_teammate: tenure.teammate,
            creator_teammate: creator_teammate,
            change_type: 'assignment_management',
            reason: reason,
            request_info: request_info
          )
          snapshot.effective_date = Date.current
          snapshot.save!

          closed_count += 1
        end
      end

      Result.ok(closed_count: closed_count)
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages.join(', '))
    rescue => e
      Result.err("Failed to close assignment tenures: #{e.message}")
    end

    private

    attr_reader :assignment, :creator_teammate, :request_info

    def bulk_close_reason
      casual_name = creator_teammate.person.casual_name
      "#{casual_name} executed a bulk action to close out all active tenures of the \"#{assignment.title}\" assignment"
    end
  end
end
