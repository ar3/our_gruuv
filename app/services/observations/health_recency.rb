# frozen_string_literal: true

module Observations
  # Given / Received recency based on latest published_at (30-day window).
  module HealthRecency
    RECENCY_DAYS = 30
    STATUSES = %w[red yellow green].freeze
    SEVERITY_ORDER = STATUSES.each_with_index.to_h.freeze

    module_function

    def status_for_last_published_at(last_published_at)
      return "red" if last_published_at.blank?
      return "green" if last_published_at >= RECENCY_DAYS.days.ago

      "yellow"
    end

    def overall_status(given_status, received_status)
      [given_status, received_status].min_by { |status| SEVERITY_ORDER.fetch(status.to_s, 0) }
    end

    def payload_for(last_published_at, observations_count: nil)
      payload = {
        "status" => status_for_last_published_at(last_published_at),
        "last_published_at" => last_published_at&.iso8601
      }
      payload["observations_count"] = observations_count unless observations_count.nil?
      payload
    end

    def payload_for_scope(scope)
      count = scope.count
      last_published_at = scope.maximum(:published_at)
      payload_for(last_published_at, observations_count: count)
    end
  end
end
