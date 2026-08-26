# frozen_string_literal: true

module Goals
  # Sends a Slack MPIM (viewer + manager + manager's manager when available) with an
  # auto-generated Goals Health nudge. Notification notifiable is the selected manager.
  class HealthNudgeService
    HEALTH_OBJECT = "goals_health"

    def self.call(organization:, manager_teammate:, nudger_company_teammate:, spotlight_stats:)
      new(
        organization: organization,
        manager_teammate: manager_teammate,
        nudger_company_teammate: nudger_company_teammate,
        spotlight_stats: spotlight_stats
      ).call
    end

    def self.last_delivered_for(manager_teammate:)
      return nil unless manager_teammate

      manager_teammate.notifications
        .goals_health_nudges
        .successful
        .where.not(message_id: nil)
        .order(created_at: :desc)
        .first
    end

    def self.skip_level_for(manager_teammate:, organization:)
      company = organization.root_company || organization
      HealthManagerPerson.manager_teammate_for(manager_teammate, company: company)
    end

    def self.recipient_teammates(manager_teammate:, nudger_company_teammate:, organization:)
      skip = skip_level_for(manager_teammate: manager_teammate, organization: organization)
      [ nudger_company_teammate, manager_teammate, skip ].compact.uniq
    end

    def initialize(organization:, manager_teammate:, nudger_company_teammate:, spotlight_stats:)
      @organization = organization
      @manager_teammate = manager_teammate
      @nudger_company_teammate = nudger_company_teammate
      @spotlight_stats = spotlight_stats
    end

    def call
      if @nudger_company_teammate.blank?
        return Result.err("You must be signed in as a teammate in this organization to send a nudge.")
      end

      intended = self.class.recipient_teammates(
        manager_teammate: @manager_teammate,
        nudger_company_teammate: @nudger_company_teammate,
        organization: @organization
      )

      missing_slack = intended.select { |tm| tm.slack_user_id.blank? }
      if missing_slack.any?
        names = missing_slack.map { |tm| tm.person&.display_name || "a recipient" }.uniq
        return Result.err(
          "Everyone on the nudge needs Slack connected (missing: #{names.to_sentence})."
        )
      end

      slack_user_ids = intended.map(&:slack_user_id).uniq
      if slack_user_ids.length < 2
        return Result.err("Need at least two distinct Slack accounts to open a group DM.")
      end

      slack_service = SlackService.new(@organization)
      dm_result = slack_service.open_or_create_group_dm(user_ids: slack_user_ids)
      return Result.err(dm_result[:error].presence || "Could not open Slack group DM.") unless dm_result[:success]

      message = HealthNudgeMessage.new(
        organization: @organization,
        manager_teammate: @manager_teammate,
        spotlight_stats: @spotlight_stats
      )

      notification = @manager_teammate.notifications.create!(
        notification_type: "goals_health_nudge",
        status: "preparing_to_send",
        metadata: {
          "channel" => dm_result[:channel_id],
          "health_object" => HEALTH_OBJECT,
          "nudger_company_teammate_id" => @nudger_company_teammate.id,
          "manager_company_teammate_id" => @manager_teammate.id,
          "recipient_company_teammate_ids" => intended.map(&:id),
          "spotlight_stats" => @spotlight_stats.stringify_keys
        },
        rich_message: message.slack_blocks,
        fallback_text: message.fallback_text
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
  end
end
