# frozen_string_literal: true

module CheckIns
  # Sends a Slack MPIM (teammate + nudger) via the OurGruuv bot when the employee
  # has latest finalized check-ins awaiting acknowledgement. Notification notifiable
  # is the employee CompanyTeammate.
  class AcknowledgementNudgeService
    include Rails.application.routes.url_helpers

    def self.call(organization:, employee_teammate:, nudger_company_teammate:)
      new(
        organization: organization,
        employee_teammate: employee_teammate,
        nudger_company_teammate: nudger_company_teammate
      ).call
    end

    def initialize(organization:, employee_teammate:, nudger_company_teammate:)
      @organization = organization
      @employee_teammate = employee_teammate
      @nudger_company_teammate = nudger_company_teammate
    end

    def call
      pending_count = AcknowledgementQueue.pending_count_for(teammate: @employee_teammate)
      return Result.err("No pending acknowledgements for this teammate.") if pending_count.zero?

      employee_slack = @employee_teammate.slack_user_id
      nudger_slack = @nudger_company_teammate.slack_user_id
      if employee_slack.blank? || nudger_slack.blank?
        return Result.err("Both you and the teammate must have Slack connected to send a nudge.")
      end

      slack_service = SlackService.new(@organization)
      dm_result = slack_service.open_or_create_group_dm(user_ids: [employee_slack, nudger_slack])
      return Result.err(dm_result[:error].presence || "Could not open Slack group DM.") unless dm_result[:success]

      channel_id = dm_result[:channel_id]
      acknowledge_url = acknowledge_organization_company_teammate_check_ins_url(
        @organization,
        @employee_teammate,
        mail_url_options
      )

      blocks = build_blocks(pending_count: pending_count, acknowledge_url: acknowledge_url)
      fallback_text = build_fallback_text(pending_count: pending_count, acknowledge_url: acknowledge_url)

      notification = @employee_teammate.notifications.create!(
        notification_type: "check_in_acknowledgement_nudge",
        status: "preparing_to_send",
        metadata: {
          "channel" => channel_id,
          "nudger_company_teammate_id" => @nudger_company_teammate.id,
          "pending_count" => pending_count
        },
        rich_message: blocks,
        fallback_text: fallback_text
      )

      post_result = slack_service.post_message(notification.id)
      if post_result[:success]
        Result.ok(notification: notification.reload)
      else
        Result.err(post_result[:error].presence || "Slack failed to post the nudge.")
      end
    rescue Slack::Web::Api::Errors::SlackError => e
      Result.err("Slack error: #{e.message}")
    rescue StandardError => e
      Result.err(e.message)
    end

    private

    def mail_url_options
      base = Rails.application.config.action_mailer.default_url_options.presence ||
             Rails.application.routes.default_url_options || {}
      base = base.symbolize_keys
      base.reverse_merge(host: "localhost", protocol: "http")
    end

    def build_blocks(pending_count:, acknowledge_url:)
      employee = @employee_teammate.person
      casual = employee&.casual_name.presence || employee&.first_name.presence || "there"
      item_word = pending_count == 1 ? "check-in" : "check-ins"

      intro = [
        "*Check-in acknowledgement*",
        "#{casual} — do you have any questions before you acknowledge? You have *#{pending_count}* #{item_word} waiting.",
        "",
        "<#{acknowledge_url}|Open acknowledgement page>"
      ].join("\n")

      [
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: intro
          }
        }
      ]
    end

    def build_fallback_text(pending_count:, acknowledge_url:)
      "Check-in acknowledgement: #{pending_count} waiting. Acknowledge: #{acknowledge_url}"
    end
  end
end
