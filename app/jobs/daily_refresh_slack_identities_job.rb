class DailyRefreshSlackIdentitiesJob < ApplicationJob
  queue_as :default

  def perform
    Organization.joins(:slack_configuration).find_each do |organization|
      next unless organization.slack_configured?

      RefreshSlackIdentitiesAutoSyncJob.perform_later(organization.id, nil, nil, 'daily')
    end
  end
end
