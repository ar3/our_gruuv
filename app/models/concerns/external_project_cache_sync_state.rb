# frozen_string_literal: true

module ExternalProjectCacheSyncState
  extend ActiveSupport::Concern

  SYNC_STATUSES = %w[pending processing completed failed].freeze
  SYNC_IN_PROGRESS_STATUSES = %w[pending processing].freeze
  SYNC_MAX_DURATION = 3.minutes
  SYNC_SLOW_WARNING_AFTER = 1.minute

  included do
    validates :sync_status, inclusion: { in: SYNC_STATUSES }, allow_nil: true
  end

  def sync_in_progress?
    sync_status.in?(SYNC_IN_PROGRESS_STATUSES)
  end

  def sync_failed?
    sync_status == "failed"
  end

  def sync_completed?
    sync_status == "completed"
  end

  def sync_stale?(threshold: SYNC_MAX_DURATION)
    sync_in_progress? && sync_started_at.present? && sync_started_at < threshold.ago
  end

  def mark_sync_failed!(message:, error_type: "unknown_error")
    update!(
      sync_status: "failed",
      sync_error: message,
      sync_error_type: error_type
    )
  end

  def mark_sync_completed!
    update!(
      sync_status: "completed",
      sync_error: nil,
      sync_error_type: nil
    )
  end

  def reconcile_stale_sync!(threshold: SYNC_MAX_DURATION)
    return self unless sync_stale?(threshold: threshold)

    mark_sync_failed!(
      error_type: "sync_timeout",
      message: "Sync timed out before finishing. Please try again."
    )
    self
  end
end
