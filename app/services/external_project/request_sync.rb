# frozen_string_literal: true

module ExternalProject
  # Marks cache as pending and enqueues background sync (1:1 Hub UI path).
  class RequestSync
    def self.call(cacheable:, source:, requested_by_teammate:)
      new(cacheable: cacheable, source: source, requested_by_teammate: requested_by_teammate).call
    end

    def initialize(cacheable:, source:, requested_by_teammate:)
      @cacheable = cacheable
      @source = source
      @requested_by_teammate = requested_by_teammate
    end

    def call
      cache = ExternalProjectCacheService.prepare_cache_record(@cacheable, @source)
      return { success: false, error: "Project ID not found" } unless cache

      if cache.sync_in_progress?
        return { success: false, error: "sync_in_progress" }
      end

      cache.assign_attributes(
        sync_status: "pending",
        sync_started_at: Time.current,
        sync_error: nil,
        sync_error_type: nil,
        last_synced_by_teammate: @requested_by_teammate
      )
      cache.save!

      SyncCacheableJob.perform_later(
        @cacheable.class.name,
        @cacheable.id,
        @source,
        @requested_by_teammate.id
      )

      { success: true, cache: cache }
    end
  end
end
