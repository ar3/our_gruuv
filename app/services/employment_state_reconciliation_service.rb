class EmploymentStateReconciliationService
  def self.call
    new.call
  end

  def call
    summary = {
      scanned_teammates: 0,
      corrected_teammates: 0,
      corrected_fields: 0,
      corrections: []
    }

    CompanyTeammate.find_each do |teammate|
      summary[:scanned_teammates] += 1

      sync_result = EmploymentStateConsistencyService.call(teammate: teammate)
      next unless sync_result.ok?

      changed_fields = Array(sync_result.value[:changed_fields])
      next if changed_fields.empty?

      summary[:corrected_teammates] += 1
      summary[:corrected_fields] += changed_fields.size
      summary[:corrections] << {
        teammate_id: teammate.id,
        changed_fields: changed_fields,
        attributes: sync_result.value[:attributes]
      }
    end

    Result.ok(summary)
  rescue => e
    Result.err("Failed to reconcile employment state: #{e.message}")
  end
end
