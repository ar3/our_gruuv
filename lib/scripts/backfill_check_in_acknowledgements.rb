# Idempotent console helper for acknowledgement backfill.
#
#   load Rails.root.join("lib/scripts/backfill_check_in_acknowledgements.rb")
#   Scripts::BackfillCheckInAcknowledgements.run(dry_run: true)
#   Scripts::BackfillCheckInAcknowledgements.run(dry_run: false)
#
# Or call the service directly (autoloaded):
#   CheckIns::BackfillAcknowledgementsFromSnapshots.call(dry_run: true)
#
module Scripts
  class BackfillCheckInAcknowledgements
    def self.run(dry_run: true)
      puts dry_run ? "DRY RUN — no rows will be updated" : "LIVE RUN — updating rows"
      result = CheckIns::BackfillAcknowledgementsFromSnapshots.call(dry_run: dry_run)
      unless result.ok?
        puts "ERROR: #{result.error}"
        return result
      end

      stats = result.value
      puts "Scanned: #{stats[:scanned]}"
      puts "Would update / updated: #{stats[:updated]}"
      puts "Skipped: #{stats[:skipped]}"
      stats[:by_type].each do |type, count|
        puts "  #{type}: #{count}"
      end
      result
    end
  end
end
