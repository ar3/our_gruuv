# frozen_string_literal: true

module SlackPogoAutoRefresh
  # Daily: reconcile hub DR churn, then enqueue due enrollments.
  class ScheduleJob < ApplicationJob
    queue_as :default

    def perform
      CompanyTeammate.where(slack_pogo_auto_refresh_hub_enabled: true).find_each do |runner|
        SyncHub.reconcile_if_enabled(runner: runner)
      end

      SlackPogoAutoRefreshEnrollment.due.find_each do |enrollment|
        RefreshEnrollmentJob.perform_later(enrollment.id)
      end
    end
  end
end
