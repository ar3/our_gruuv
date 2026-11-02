# frozen_string_literal: true

module SlackPogoAutoRefresh
  # Turns hub on/off and reconciles hub enrollments to self + current DRs.
  class SyncHub
    Result = Data.define(:ok?, :error, :needs_slack_oauth)

    def self.enable(runner:)
      new(runner: runner).enable
    end

    def self.disable(runner:)
      new(runner: runner).disable
    end

    def self.reconcile_if_enabled(runner:)
      new(runner: runner).reconcile_if_enabled
    end

    def initialize(runner:)
      @runner = runner
      @organization = runner&.organization
    end

    def enable
      return Result.new(ok?: false, error: "Not signed in.", needs_slack_oauth: false) if @runner.nil?
      return Result.new(ok?: false, error: "Connect Slack (search) first.", needs_slack_oauth: true) unless @runner.has_slack_search_identity?

      @runner.update!(slack_pogo_auto_refresh_hub_enabled: true)
      reconcile_hub_enrollments!
      Result.new(ok?: true, error: nil, needs_slack_oauth: false)
    end

    def disable
      return Result.new(ok?: false, error: "Not signed in.", needs_slack_oauth: false) if @runner.nil?

      @runner.update!(slack_pogo_auto_refresh_hub_enabled: false)
      SlackPogoAutoRefreshEnrollment.hub.where(runner_company_teammate_id: @runner.id).delete_all
      Result.new(ok?: true, error: nil, needs_slack_oauth: false)
    end

    def reconcile_if_enabled
      return unless @runner&.slack_pogo_auto_refresh_hub_enabled?

      reconcile_hub_enrollments!
    end

    private

    def reconcile_hub_enrollments!
      subjects = HubSubjects.call(runner: @runner)
      subject_ids = subjects.map(&:id)

      subjects.each do |subject|
        enrollment = SlackPogoAutoRefreshEnrollment.find_or_initialize_by(
          runner_company_teammate_id: @runner.id,
          subject_company_teammate_id: subject.id
        )
        enrollment.organization = @organization
        enrollment.source = SlackPogoAutoRefreshEnrollment::SOURCE_HUB
        enrollment.save!
      end

      SlackPogoAutoRefreshEnrollment.hub
                                    .where(runner_company_teammate_id: @runner.id)
                                    .where.not(subject_company_teammate_id: subject_ids)
                                    .delete_all
    end
  end
end
