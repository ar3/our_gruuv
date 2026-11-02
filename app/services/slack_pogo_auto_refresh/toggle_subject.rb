# frozen_string_literal: true

module SlackPogoAutoRefresh
  # Per-subject manual opt-in on Source from Slack. Hub-covered subjects stay locked.
  class ToggleSubject
    Result = Data.define(:ok?, :enabled?, :error, :needs_slack_oauth, :locked_by_hub)

    def self.call(runner:, subject:, enable:)
      new(runner: runner, subject: subject, enable: enable).call
    end

    def initialize(runner:, subject:, enable:)
      @runner = runner
      @subject = subject
      @enable = ActiveModel::Type::Boolean.new.cast(enable)
    end

    def call
      return Result.new(ok?: false, enabled?: false, error: "Not signed in.", needs_slack_oauth: false, locked_by_hub: false) if @runner.nil?
      return Result.new(ok?: false, enabled?: false, error: "Missing subject.", needs_slack_oauth: false, locked_by_hub: false) if @subject.nil?

      if hub_covers_subject?
        return Result.new(
          ok?: false,
          enabled?: true,
          error: "This person is covered by your hub auto-refresh (self / direct reports) and can’t be turned off while hub is on.",
          needs_slack_oauth: false,
          locked_by_hub: true
        )
      end

      if @enable
        return Result.new(ok?: false, enabled?: false, error: "Connect Slack (search) first.", needs_slack_oauth: true, locked_by_hub: false) unless @runner.has_slack_search_identity?

        enrollment = SlackPogoAutoRefreshEnrollment.find_or_initialize_by(
          runner_company_teammate_id: @runner.id,
          subject_company_teammate_id: @subject.id
        )
        enrollment.organization = @runner.organization
        enrollment.source = SlackPogoAutoRefreshEnrollment::SOURCE_MANUAL
        enrollment.save!
        Result.new(ok?: true, enabled?: true, error: nil, needs_slack_oauth: false, locked_by_hub: false)
      else
        SlackPogoAutoRefreshEnrollment.where(
          runner_company_teammate_id: @runner.id,
          subject_company_teammate_id: @subject.id
        ).delete_all
        Result.new(ok?: true, enabled?: false, error: nil, needs_slack_oauth: false, locked_by_hub: false)
      end
    end

    private

    def hub_covers_subject?
      return false unless @runner.slack_pogo_auto_refresh_hub_enabled?

      HubSubjects.call(runner: @runner).map(&:id).include?(@subject.id)
    end
  end
end
