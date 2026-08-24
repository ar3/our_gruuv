# frozen_string_literal: true

module CheckIns
  # Latest finalized check-ins (per position / assignment / aspiration) that still
  # need employee acknowledgement. Shared by acknowledge page, GSD, health, nudges.
  class AcknowledgementQueue
    Result = Struct.new(
      :position_check_in,
      :assignment_check_ins,
      :aspiration_check_ins,
      keyword_init: true
    ) do
      def items
        [*aspiration_check_ins, *assignment_check_ins, position_check_in].compact
      end

      def count
        items.size
      end

      def any?
        count.positive?
      end
    end

    def self.for(teammate:)
      new(teammate: teammate).call
    end

    def self.pending_count_for(teammate:)
      return 0 if teammate.blank?

      self.for(teammate: teammate).count
    end

    # Returns { teammate_id => pending_count } for batch surfaces (nudges index).
    def self.pending_counts_by_teammate_id(teammate_ids:)
      ids = Array(teammate_ids).compact.map(&:to_i).uniq
      return {} if ids.empty?

      counts = Hash.new(0)
      count_pending_latest_positions(ids).each { |tid| counts[tid] += 1 }
      count_pending_latest_assignments(ids).each { |tid| counts[tid] += 1 }
      count_pending_latest_aspirations(ids).each { |tid| counts[tid] += 1 }
      counts
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

    def self.count_pending_latest_positions(teammate_ids)
      sql = ActiveRecord::Base.sanitize_sql_array([<<~SQL.squish, teammate_ids])
        SELECT teammate_id FROM (
          SELECT DISTINCT ON (teammate_id) teammate_id, employee_acknowledged_at
          FROM position_check_ins
          WHERE teammate_id IN (?)
            AND official_check_in_completed_at IS NOT NULL
          ORDER BY teammate_id, official_check_in_completed_at DESC, id DESC
        ) latest
        WHERE employee_acknowledged_at IS NULL
      SQL
      ActiveRecord::Base.connection.select_values(sql).map(&:to_i)
    end
    private_class_method :count_pending_latest_positions

    def self.count_pending_latest_assignments(teammate_ids)
      sql = ActiveRecord::Base.sanitize_sql_array([<<~SQL.squish, teammate_ids])
        SELECT teammate_id FROM (
          SELECT DISTINCT ON (teammate_id, assignment_id) teammate_id, employee_acknowledged_at
          FROM assignment_check_ins
          WHERE teammate_id IN (?)
            AND official_check_in_completed_at IS NOT NULL
          ORDER BY teammate_id, assignment_id, official_check_in_completed_at DESC, id DESC
        ) latest
        WHERE employee_acknowledged_at IS NULL
      SQL
      ActiveRecord::Base.connection.select_values(sql).map(&:to_i)
    end
    private_class_method :count_pending_latest_assignments

    def self.count_pending_latest_aspirations(teammate_ids)
      sql = ActiveRecord::Base.sanitize_sql_array([<<~SQL.squish, teammate_ids])
        SELECT teammate_id FROM (
          SELECT DISTINCT ON (teammate_id, aspiration_id) teammate_id, employee_acknowledged_at
          FROM aspiration_check_ins
          WHERE teammate_id IN (?)
            AND official_check_in_completed_at IS NOT NULL
          ORDER BY teammate_id, aspiration_id, official_check_in_completed_at DESC, id DESC
        ) latest
        WHERE employee_acknowledged_at IS NULL
      SQL
      ActiveRecord::Base.connection.select_values(sql).map(&:to_i)
    end
    private_class_method :count_pending_latest_aspirations

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
