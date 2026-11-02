# frozen_string_literal: true

module SlackPogoAutoRefresh
  # Starts a 14-day Slack search + auto-extract for one enrollment.
  class StartRefresh
    def self.call(enrollment:)
      new(enrollment: enrollment).call
    end

    def initialize(enrollment:)
      @enrollment = enrollment
      @runner = enrollment.runner_company_teammate
      @subject = enrollment.subject_company_teammate
    end

    def call
      return false unless @runner&.has_slack_search_identity?
      return false if @subject.nil?

      window = SlackPogoAutoRefreshEnrollment::WINDOW_DAYS
      search = PossibleObservationSlackSearch.create!(
        organization: @enrollment.organization,
        creator_company_teammate: @runner,
        subject_company_teammate: @subject,
        window_days: window,
        display_name: "Auto-refresh about #{@subject.person.casual_name} (last #{window} days) — #{Time.current.strftime('%Y-%m-%d %H:%M')}",
        search_status: "pending",
        extraction_status: "ready",
        auto_extract_after_search: true
      )
      PossibleObservationSlackSearchJob.perform_later(search.id)
      @enrollment.mark_refreshed!
      true
    end
  end
end
