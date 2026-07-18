# frozen_string_literal: true

module OgConsultations
  # Shared JSON for Consult OG / OGO extraction status polling.
  class StatusPayload
    SLOW_AFTER_SECONDS = 90
    STALE_AFTER_SECONDS = 240

    def self.for_consultation(consultation, status: nil, **extras)
      new.for_consultation(consultation, status: status, **extras)
    end

    def self.for_heartbeat(record:, status:, **extras)
      new.for_heartbeat(record: record, status: status, **extras)
    end

    def for_consultation(consultation, status: nil, **extras)
      status_value = (status.presence || consultation.status).to_s
      reference_time = consultation.started_at || consultation.updated_at || consultation.created_at
      elapsed_seconds = [(Time.current - reference_time).to_i, 0].max
      eta = consultation.in_flight? ? EtaEstimator.call(consultation) : nil

      {
        id: consultation.id,
        status: status_value,
        elapsed_seconds: elapsed_seconds,
        stale: status_value == 'processing' && elapsed_seconds > STALE_AFTER_SECONDS,
        slow: %w[pending processing].include?(status_value) && elapsed_seconds > SLOW_AFTER_SECONDS,
        updated_at: consultation.updated_at&.iso8601,
        units_total: consultation.units_total.to_i,
        units_completed: consultation.units_completed.to_i,
        estimated_duration_seconds: eta&.estimated_duration_seconds,
        eta_confidence: eta&.eta_confidence
      }.merge(extras)
    end

    def for_heartbeat(record:, status:, **extras)
      status_value = status.to_s
      reference_time =
        case status_value
        when 'processing'
          record.updated_at || record.created_at
        when 'pending'
          record.created_at
        else
          record.updated_at || record.created_at
        end
      elapsed_seconds = [(Time.current - reference_time).to_i, 0].max

      {
        id: record.id,
        status: status_value,
        elapsed_seconds: elapsed_seconds,
        stale: status_value == 'processing' && elapsed_seconds > STALE_AFTER_SECONDS,
        slow: %w[pending processing].include?(status_value) && elapsed_seconds > SLOW_AFTER_SECONDS,
        updated_at: record.updated_at&.iso8601,
        units_total: nil,
        units_completed: nil,
        estimated_duration_seconds: nil,
        eta_confidence: nil
      }.merge(extras)
    end
  end
end
