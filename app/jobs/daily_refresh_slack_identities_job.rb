class DailyRefreshSlackIdentitiesJob < ApplicationJob
  queue_as :default

  def perform
    system_person_id = SystemActor.person.id

    Organization.joins(:slack_configuration).find_each do |organization|
      next unless organization.slack_configured?

      RefreshSlackIdentitiesAutoSyncJob.perform_later(organization.id, system_person_id, system_person_id, 'daily')
    end
  end
end
