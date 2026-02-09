# frozen_string_literal: true

class DailyOperationalCleanupJob < ApplicationJob
  queue_as :default

  def perform
    ObserveBirthdaysJob.perform_and_get_result
    ObserveWorkAnniversariesJob.perform_and_get_result
  end
end
