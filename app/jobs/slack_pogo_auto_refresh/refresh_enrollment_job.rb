# frozen_string_literal: true

module SlackPogoAutoRefresh
  class RefreshEnrollmentJob < ApplicationJob
    queue_as :default

    def perform(enrollment_id)
      enrollment = SlackPogoAutoRefreshEnrollment.find_by(id: enrollment_id)
      return if enrollment.nil?
      return unless enrollment.due?

      StartRefresh.call(enrollment: enrollment)
    end
  end
end
