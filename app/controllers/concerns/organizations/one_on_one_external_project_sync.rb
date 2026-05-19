# frozen_string_literal: true

module Organizations
  module OneOnOneExternalProjectSync
    extend ActiveSupport::Concern

    private

    def one_on_one_hub_path(anchor: nil)
      organization_company_teammate_one_on_one_link_path(
        organization,
        @teammate,
        anchor: anchor
      )
    end

    def enqueue_one_on_one_asana_sync!(source:)
      result = ExternalProject::RequestSync.call(
        cacheable: @one_on_one_link,
        source: source,
        requested_by_teammate: current_company_teammate
      )

      if result[:success]
        flash[:external_project_sync_poll] = source
        redirect_to one_on_one_hub_path(anchor: "sync"),
                    notice: "Project sync started. This section will update when processing finishes."
      elsif result[:error] == "sync_in_progress"
        redirect_to one_on_one_hub_path(anchor: "sync"),
                    alert: "A sync is already in progress. Please wait for it to finish."
      else
        redirect_to one_on_one_hub_path(anchor: "sync"),
                    alert: result[:error] || "Could not start project sync."
      end
    end

    def maybe_enqueue_asana_sync_after_save!
      source = @one_on_one_link.external_project_source
      return unless source == "asana"
      return unless current_company_teammate&.has_asana_identity?

      result = ExternalProject::RequestSync.call(
        cacheable: @one_on_one_link,
        source: source,
        requested_by_teammate: current_company_teammate
      )
      flash[:external_project_sync_poll] = source if result[:success]
    end

    def load_external_project_cache_for_hub
      @source = @one_on_one_link&.external_project_source
      return unless @source.present?

      @external_project_cache = ExternalProjectCache.find_by(cacheable: @one_on_one_link, source: @source)
      @poll_external_project_sync = flash[:external_project_sync_poll].to_s == @source.to_s
    end

    def external_project_sync_status_json(cache)
      cache.reconcile_stale_sync!
      status = cache.sync_status.to_s.presence || "none"
      reference_time =
        case status
        when "processing"
          cache.updated_at || cache.sync_started_at || cache.created_at
        when "pending"
          cache.sync_started_at || cache.updated_at || cache.created_at
        else
          cache.sync_started_at || cache.updated_at || cache.created_at
        end
      elapsed_seconds = [(Time.current - reference_time).to_i, 0].max
      stale = ExternalProjectCache::SYNC_IN_PROGRESS_STATUSES.include?(status) &&
              elapsed_seconds > ExternalProjectCache::SYNC_MAX_DURATION.to_i
      slow = ExternalProjectCache::SYNC_IN_PROGRESS_STATUSES.include?(status) &&
             elapsed_seconds > ExternalProjectCache::SYNC_SLOW_WARNING_AFTER.to_i

      {
        status: status,
        error_message: cache.sync_error,
        error_type: cache.sync_error_type,
        elapsed_seconds: elapsed_seconds,
        stale: stale,
        slow: slow,
        updated_at: cache.updated_at&.iso8601
      }
    end
  end
end
