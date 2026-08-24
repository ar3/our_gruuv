# frozen_string_literal: true

# Idempotent backfill: closed check-ins linked to acknowledged snapshots → Agree.
#
# Console:
#   CheckIns::BackfillAcknowledgementsFromSnapshots.call(dry_run: true)
#   CheckIns::BackfillAcknowledgementsFromSnapshots.call(dry_run: false)
#
module CheckIns
  class BackfillAcknowledgementsFromSnapshots
    CHECK_IN_CLASSES = [PositionCheckIn, AssignmentCheckIn, AspirationCheckIn].freeze

    def self.call(dry_run: true)
      new(dry_run: dry_run).call
    end

    def initialize(dry_run:)
      @dry_run = dry_run
    end

    def call
      stats = { scanned: 0, updated: 0, skipped: 0, by_type: Hash.new(0) }

      CHECK_IN_CLASSES.each do |klass|
        scope = klass
          .closed
          .where.not(maap_snapshot_id: nil)
          .where(employee_acknowledged_at: nil)
          .joins(:maap_snapshot)
          .where.not(maap_snapshots: { employee_acknowledged_at: nil })
          .includes(:maap_snapshot)

        scope.find_each do |check_in|
          stats[:scanned] += 1
          snapshot = check_in.maap_snapshot
          if check_in.employee_acknowledged?
            stats[:skipped] += 1
            next
          end

          attrs = build_attrs(snapshot)
          if @dry_run
            stats[:updated] += 1
            stats[:by_type][klass.name] += 1
          else
            check_in.update_columns(attrs)
            stats[:updated] += 1
            stats[:by_type][klass.name] += 1
          end
        end
      end

      stats[:dry_run] = @dry_run
      Result.ok(stats)
    end

    private

    def build_attrs(snapshot)
      request_info = normalize_request_info(snapshot)
      {
        employee_acknowledged_at: snapshot.employee_acknowledged_at,
        employee_acknowledgement: "agree",
        employee_acknowledgement_request_info: request_info,
        updated_at: Time.current
      }
    end

    def normalize_request_info(snapshot)
      existing = snapshot.employee_acknowledgement_request_info
      existing = existing.to_h if existing.respond_to?(:to_h)
      existing = {} unless existing.is_a?(Hash)
      existing = existing.stringify_keys

      existing.except("acknowledged_by").merge(
        "request_source" => "migrated_from_snapshot",
        "snapshot_id" => snapshot.id,
        "acknowledged_at" => snapshot.employee_acknowledged_at&.iso8601
      )
    end
  end
end
