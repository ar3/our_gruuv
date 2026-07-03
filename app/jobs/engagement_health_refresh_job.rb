# frozen_string_literal: true

class EngagementHealthRefreshJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: ->(teammate_id) { "engagement_health_#{teammate_id}" }

  def perform(teammate_id)
    teammate = CompanyTeammate.find_by(id: teammate_id)
    return unless teammate&.organization

    EngagementHealth::Refresher.call(teammate)
  end
end
