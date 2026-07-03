# frozen_string_literal: true

class EngagementHealthLiveCacheBackfillJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: ->(organization_id, *) { "engagement_health_live_cache_#{organization_id}" }

  def perform(organization_id, teammate_ids)
    organization = Organization.find_by(id: organization_id)
    return unless organization

    CompanyTeammate.where(id: Array(teammate_ids), organization: organization).find_each do |teammate|
      EngagementHealth::Refresher.call(teammate, organization)
    end
  end
end
