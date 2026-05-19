# frozen_string_literal: true

module ExternalProject
  class SyncCacheableJob < ApplicationJob
    queue_as :default

    # Do not re-raise after marking the cache failed — avoids retries leaving sync stuck in progress.
    rescue_from StandardError, with: :handle_sync_failure

    def perform(cacheable_type, cacheable_id, source, sync_teammate_id)
      @cacheable = cacheable_type.constantize.find_by(id: cacheable_id)
      @sync_teammate = CompanyTeammate.find_by(id: sync_teammate_id)
      @source = source
      return if @cacheable.nil? || @sync_teammate.nil?

      @cache = ExternalProjectCache.find_by(cacheable: @cacheable, source: @source)
      unless @cache
        Rails.logger.warn(
          "ExternalProject::SyncCacheableJob: no cache for #{cacheable_type}##{cacheable_id} (#{source})"
        )
        return
      end

      unless @cache.sync_in_progress? || @cache.sync_status == "pending"
        Rails.logger.info(
          "ExternalProject::SyncCacheableJob: skipping cache #{@cache.id} with status=#{@cache.sync_status}"
        )
        return
      end

      result = PerformSync.call(
        cacheable: @cacheable,
        source: @source,
        sync_teammates: [@sync_teammate],
        cache: @cache,
        update_ui_status: true
      )

      @cache.reload
      if @cache.sync_in_progress?
        @cache.mark_sync_failed!(
          error_type: "sync_incomplete",
          message: "Sync ended unexpectedly. Please try again."
        )
        Rails.logger.warn(
          "ExternalProject::SyncCacheableJob: cache #{@cache.id} still in progress after PerformSync: #{result.inspect}"
        )
      elsif result[:success]
        Rails.logger.info "ExternalProject::SyncCacheableJob: sync completed for cache #{@cache.id}"
      else
        Rails.logger.warn(
          "ExternalProject::SyncCacheableJob: sync failed for cache #{@cache.id}: " \
          "#{result[:errors]&.map { |e| e[:error] }&.join(', ')}"
        )
      end
    end

    private

    def handle_sync_failure(exception)
      Sentry.capture_exception(exception) do |event|
        event.set_context("job", {
          class: self.class.name,
          job_id: job_id,
          arguments: arguments,
          cache_id: @cache&.id
        })
      end

      if @cache&.sync_in_progress?
        @cache.mark_sync_failed!(
          error_type: "exception",
          message: ExternalProject::SyncErrorMessage.for(
            { error: exception.message, error_type: "exception" },
            @source
          )
        )
      end

      Rails.logger.error(
        "ExternalProject::SyncCacheableJob: #{exception.class}: #{exception.message}"
      )
    end
  end
end
