# frozen_string_literal: true

class ObservationHealthCacheRefreshJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: ->(teammate_id) { "observation_health_cache_#{teammate_id}" }

  def perform(teammate_id)
    teammate = CompanyTeammate.find_by(id: teammate_id)
    return unless teammate

    organization = teammate.organization
    return unless organization

    ObservationHealthCacheBuilder.new(teammate, organization).build_and_save
  end
end
