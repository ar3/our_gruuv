# frozen_string_literal: true

class CheckInHealthCacheRefreshJob < ApplicationJob
  queue_as :default

  # Only one refresh per teammate at a time (Solid Queue concurrency)
  limits_concurrency to: 1, key: ->(teammate_id) { "check_in_health_cache_#{teammate_id}" }

  def perform(teammate_id)
    teammate = CompanyTeammate.find_by(id: teammate_id)
    return unless teammate

    organization = teammate.organization
    return unless organization

    CheckInHealthCacheBuilder.new(teammate, organization).build_and_save
  end
end
