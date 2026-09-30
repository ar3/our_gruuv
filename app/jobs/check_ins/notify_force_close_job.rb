# frozen_string_literal: true

module CheckIns
  # Slack group DM (employee + employment manager) when an assignment check-in is force closed.
  class NotifyForceCloseJob < ApplicationJob
    queue_as :default

    def perform(check_in_id:, organization_id:, closed_by_teammate_id:)
      organization = Organization.find(organization_id)
      check_in = AssignmentCheckIn.find_by(id: check_in_id)
      return unless check_in

      closed_by_teammate = CompanyTeammate.find_by(id: closed_by_teammate_id)
      employee_teammate = check_in.teammate
      employment_tenure = employee_teammate.employment_tenures.active.where(company: organization).first
      manager_teammate = employment_tenure&.manager_teammate
      return unless manager_teammate

      return unless employee_teammate.has_slack_identity? && employee_teammate.slack_user_id.present?
      return unless manager_teammate.has_slack_identity? && manager_teammate.slack_user_id.present?

      slack_service = SlackService.new(organization)
      group_dm_result = slack_service.open_or_create_group_dm(
        user_ids: [employee_teammate.slack_user_id, manager_teammate.slack_user_id]
      )
      unless group_dm_result[:success]
        Rails.logger.error "Failed to open group DM for check-in force close: #{group_dm_result[:error]}"
        return
      end

      channel_id = group_dm_result[:channel_id]
      message_text = build_message_text(
        check_in: check_in,
        organization: organization,
        employee_teammate: employee_teammate,
        closed_by_teammate: closed_by_teammate
      )

      notification = Notification.create!(
        notifiable: check_in,
        notification_type: "check_in_force_close",
        status: "preparing_to_send",
        metadata: {
          "channel" => channel_id,
          "closed_by_teammate_id" => closed_by_teammate_id,
          "employee_teammate_id" => employee_teammate.id,
          "manager_teammate_id" => manager_teammate.id
        },
        fallback_text: message_text
      )

      post_result = slack_service.post_group_dm(channel_id: channel_id, text: message_text)
      unless post_result[:success]
        Rails.logger.error "Failed to post group DM for check-in force close: #{post_result[:error]}"
        notification.update!(status: "send_failed")
        return
      end

      notification.update!(
        message_id: post_result[:message_id],
        status: "sent_successfully"
      )
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Check-in force close notify missing record: #{e.message}"
    rescue StandardError => e
      Rails.logger.error "Unexpected error in NotifyForceCloseJob: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end

    private

    def build_message_text(check_in:, organization:, employee_teammate:, closed_by_teammate:)
      assignment_name = check_in.assignment.display_name
      check_in_url = Rails.application.routes.url_helpers.organization_teammate_assignment_url(
        organization,
        employee_teammate,
        check_in.assignment,
        anchor: "research-all-check-ins",
        **url_options
      )
      closer = closed_by_teammate&.person&.casual_name.presence || "Someone"
      "#{closer} force closed the #{assignment_name} check-in. No data was lost — you can always get back to it in the <#{check_in_url}|All check-ins> section."
    end

    def url_options
      base = Rails.application.config.action_mailer.default_url_options.presence ||
             Rails.application.routes.default_url_options || {}
      base = base.symbolize_keys
      base.reverse_merge(host: "localhost", protocol: "http")
    end
  end
end
