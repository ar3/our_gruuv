# frozen_string_literal: true

module CheckIns
  # Sends a Slack MPIM (teammate + nudger) via the OurGruuv bot, anchored on the latest
  # unacknowledged MaapSnapshot. History lives on Notification rows (notifiable = anchor snapshot).
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
      pending_scope = MaapSnapshot.pending_acknowledgement_for(@employee_teammate)
        .order(effective_date: :desc, id: :desc)
      return Result.err('No pending acknowledgements for this teammate.') if pending_scope.none?

      pending = pending_scope.to_a
      anchor = pending.first

      employee_slack = @employee_teammate.slack_user_id
      nudger_slack = @nudger_company_teammate.slack_user_id
      if employee_slack.blank? || nudger_slack.blank?
        return Result.err('Both you and the teammate must have Slack connected to send a nudge.')
      end

      slack_service = SlackService.new(@organization)
      dm_result = slack_service.open_or_create_group_dm(user_ids: [employee_slack, nudger_slack])
      return Result.err(dm_result[:error].presence || 'Could not open Slack group DM.') unless dm_result[:success]

      channel_id = dm_result[:channel_id]
      audit_url = audit_organization_employee_url(
        @organization,
        @employee_teammate,
        audit_mail_url_options
      )

      blocks = build_blocks(pending_snapshots: pending, audit_url: audit_url)
      fallback_text = build_fallback_text(pending_snapshots: pending, audit_url: audit_url)

      notification = anchor.notifications.create!(
        notification_type: 'check_in_acknowledgement_nudge',
        status: 'preparing_to_send',
        metadata: {
          'channel' => channel_id,
          'nudger_company_teammate_id' => @nudger_company_teammate.id
        },
        rich_message: blocks,
        fallback_text: fallback_text
      )

      post_result = slack_service.post_message(notification.id)
      if post_result[:success]
        Result.ok(notification: notification.reload)
      else
        Result.err(post_result[:error].presence || 'Slack failed to post the nudge.')
      end
    rescue Slack::Web::Api::Errors::SlackError => e
      Result.err("Slack error: #{e.message}")
    rescue StandardError => e
      Result.err(e.message)
    end

    private

    def audit_mail_url_options
      base = Rails.application.config.action_mailer.default_url_options.presence ||
             Rails.application.routes.default_url_options || {}
      base = base.symbolize_keys
      base.reverse_merge(host: 'localhost', protocol: 'http')
    end

    def build_blocks(pending_snapshots:, audit_url:)
      employee = @employee_teammate.person
      casual = employee&.casual_name.presence || employee&.first_name.presence || 'there'
      bullet_lines = pending_snapshots.map { |s| "• #{snapshot_line(s)}" }.join("\n")

      intro = [
        '*Check-in acknowledgement*',
        "#{casual} — do you have any questions before you acknowledge? Here's what's waiting:",
        bullet_lines,
        "",
        "<#{audit_url}|Open acknowledgement page>"
      ].join("\n")

      [
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: intro
          }
        }
      ]
    end

    def build_fallback_text(pending_snapshots:, audit_url:)
      lines = pending_snapshots.map { |s| snapshot_line(s) }.join('; ')
      "Check-in acknowledgement: #{lines}. Acknowledge: #{audit_url}"
    end

    def snapshot_line(snapshot)
      date_part = snapshot.effective_date&.strftime('%b %d, %Y') || '—'
      "#{date_part} — #{snapshot.change_type.to_s.humanize} — #{snapshot.reason.to_s.truncate(120, omission: '…')}"
    end
  end
end
