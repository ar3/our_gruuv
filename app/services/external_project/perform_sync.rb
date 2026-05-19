# frozen_string_literal: true

module ExternalProject
  # Runs ExternalProjectCacheService.sync_project for one or more teammates (digest: employee then manager).
  class PerformSync
    SYNC_TIMEOUT_SECONDS = ExternalProjectCache::SYNC_MAX_DURATION.to_i

    def self.call(cacheable:, source:, sync_teammates:, cache: nil, update_ui_status: true)
      new(
        cacheable: cacheable,
        source: source,
        sync_teammates: sync_teammates,
        cache: cache,
        update_ui_status: update_ui_status
      ).call
    end

    def initialize(cacheable:, source:, sync_teammates:, cache: nil, update_ui_status: true)
      @cacheable = cacheable
      @source = source
      @sync_teammates = Array(sync_teammates).compact.uniq(&:id)
      @cache = cache
      @update_ui_status = update_ui_status
    end

    def call
      return failure(:no_sync_teammates) if @sync_teammates.empty?

      @cache ||= ExternalProjectCacheService.prepare_cache_record(@cacheable, @source) if @update_ui_status
      mark_processing! if @update_ui_status && @cache

      run_sync_with_timeout
    rescue StandardError => e
      Rails.logger.error "ExternalProject::PerformSync error: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      mark_failed_from_exception!(e)
      { success: false, errors: [{ error: e.message, error_type: "exception" }] }
    end

    private

    def run_sync_with_timeout
      result =
        if @update_ui_status
          Timeout.timeout(SYNC_TIMEOUT_SECONDS) { perform_sync_attempts }
        else
          perform_sync_attempts
        end
      finalize_result!(result)
      result
    rescue Timeout::Error
      mark_failed_from_error_hash!(
        error: "Sync timed out after #{SYNC_TIMEOUT_SECONDS} seconds",
        error_type: "sync_timeout"
      )
      { success: false, errors: [{ error: "Sync timed out", error_type: "sync_timeout" }] }
    end

    def perform_sync_attempts
      errors = []
      @sync_teammates.each do |teammate|
        result = ExternalProjectCacheService.sync_project(@cacheable, @source, teammate)
        if result[:success]
          mark_completed!
          return { success: true, synced_by_teammate_id: teammate.id, cache: result[:cache] }
        end

        errors << {
          teammate_id: teammate.id,
          error: result[:error],
          error_type: result[:error_type] || "unknown_error"
        }
      end

      mark_failed_from_error_hash!(errors.last) if errors.any?
      { success: false, errors: errors }
    end

    def finalize_result!(result)
      return if result[:success]
      return unless @update_ui_status && @cache

      @cache.reload
      return unless @cache.sync_in_progress?

      error = result[:errors]&.last
      if result[:skipped]
        mark_failed_from_error_hash!(
          error: "Sync could not be started (#{result[:skipped]})",
          error_type: "sync_skipped"
        )
      elsif error.blank?
        mark_failed_from_error_hash!(
          error: "Sync ended without completing",
          error_type: "sync_incomplete"
        )
      end
    end

    def mark_processing!
      @cache.update!(sync_status: "processing")
    end

    def mark_completed!
      @cache.mark_sync_completed!
    end

    def mark_failed_from_error_hash!(error)
      return unless @update_ui_status && @cache && error.present?

      @cache.mark_sync_failed!(
        message: SyncErrorMessage.for(error, @source),
        error_type: error[:error_type].to_s
      )
    end

    def mark_failed_from_exception!(exception)
      mark_failed_from_error_hash!(
        error: exception.message,
        error_type: "exception"
      )
    end

    def failure(reason)
      result = { success: false, skipped: reason, errors: [] }
      finalize_result!(result)
      result
    end
  end
end
