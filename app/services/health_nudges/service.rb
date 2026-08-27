# frozen_string_literal: true

module HealthNudges
  # Sends a Slack MPIM with an auto-generated health nudge.
  # Recipient scopes:
  #   "manager" — viewer + selected manager
  #   "manager_and_skip" — viewer + selected manager + manager's manager
  # Optional employee_entries become one Slack thread reply each (profile + status + detail).
  class Service
    RECIPIENT_SCOPES = %w[manager manager_and_skip].freeze
    NOTIFICATION_TYPE = "health_nudge"
    LEGACY_GOALS_NOTIFICATION_TYPE = "goals_health_nudge"

    def self.call(organization:, health_object:, manager_teammate:, nudger_company_teammate:, spotlight_stats:, recipient_scope:, employee_entries: [])
      new(
        organization: organization,
        health_object: health_object,
        manager_teammate: manager_teammate,
        nudger_company_teammate: nudger_company_teammate,
        spotlight_stats: spotlight_stats,
        recipient_scope: recipient_scope,
        employee_entries: employee_entries
      ).call
    end

    def self.last_delivered_for(manager_teammate:, health_object:)
      return nil unless manager_teammate

      object = health_object.to_s
      manager_teammate.notifications
        .where(notification_type: notification_types_for(object))
        .successful
        .where.not(message_id: nil)
        .where(main_thread_id: nil)
        .where("metadata ->> 'health_object' = ? OR (metadata ->> 'health_object' IS NULL AND ? = 'goals_health')", object, object)
        .order(created_at: :desc)
        .first
    end

    def self.notification_types_for(health_object)
      if health_object.to_s == "goals_health"
        [ NOTIFICATION_TYPE, LEGACY_GOALS_NOTIFICATION_TYPE ]
      else
        [ NOTIFICATION_TYPE ]
      end
    end

    def self.skip_level_for(manager_teammate:, organization:)
      company = organization.root_company || organization
      Goals::HealthManagerPerson.manager_teammate_for(manager_teammate, company: company)
    end

    def self.normalize_recipient_scope(scope)
      value = scope.to_s
      return value if RECIPIENT_SCOPES.include?(value)

      nil
    end

    def self.recipient_teammates(manager_teammate:, nudger_company_teammate:, organization:, recipient_scope:)
      scope = normalize_recipient_scope(recipient_scope)
      return [] if scope.blank?

      list = [ nudger_company_teammate, manager_teammate ]
      if scope == "manager_and_skip"
        list << skip_level_for(manager_teammate: manager_teammate, organization: organization)
      end
      list.compact.uniq
    end

    def self.spotlight_stats_from_protect_flow_plan(plan)
      progress = plan.fetch(:progress)
      people_count = progress[:people_count].to_i
      healthy = progress[:healthy_people_count].to_i
      {
        total_employees: people_count,
        healthy_count: healthy,
        warning_count: 0,
        needs_attention_count: people_count - healthy,
        ok_count: 0,
        concerning_count: people_count - healthy,
        current_unhealthy_vectors: progress[:current_unhealthy_count].to_i,
        improved_vector_count: progress[:improved_vector_count].to_i,
        start_unhealthy_count: progress[:start_unhealthy_count].to_i,
        week_start: plan[:week_start]
      }
    end

    def initialize(organization:, health_object:, manager_teammate:, nudger_company_teammate:, spotlight_stats:, recipient_scope:, employee_entries: [])
      @organization = organization
      @health_object = health_object.to_s
      @manager_teammate = manager_teammate
      @nudger_company_teammate = nudger_company_teammate
      @spotlight_stats = spotlight_stats
      @recipient_scope = self.class.normalize_recipient_scope(recipient_scope)
      @employee_entries = Array(employee_entries)
      @config = Registry.fetch(@health_object)
    end

    def call
      return Result.err("Unknown health page for nudge.") unless Registry.valid?(@health_object)

      if @nudger_company_teammate.blank?
        return Result.err("You must be signed in as a teammate in this organization to send a nudge.")
      end
      return Result.err("Choose who to include on the nudge.") if @recipient_scope.blank?

      if @recipient_scope == "manager_and_skip" &&
         self.class.skip_level_for(manager_teammate: @manager_teammate, organization: @organization).blank?
        return Result.err("This manager has no manager on file, so that send option is unavailable.")
      end

      intended = self.class.recipient_teammates(
        manager_teammate: @manager_teammate,
        nudger_company_teammate: @nudger_company_teammate,
        organization: @organization,
        recipient_scope: @recipient_scope
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

      channel_id = dm_result[:channel_id]
      message = Message.new(
        health_object: @health_object,
        organization: @organization,
        manager_teammate: @manager_teammate,
        spotlight_stats: @spotlight_stats,
        employee_count: @employee_entries.size
      )

      shared_metadata = {
        "channel" => channel_id,
        "health_object" => @health_object,
        "recipient_scope" => @recipient_scope,
        "nudger_company_teammate_id" => @nudger_company_teammate.id,
        "manager_company_teammate_id" => @manager_teammate.id,
        "recipient_company_teammate_ids" => intended.map(&:id),
        "spotlight_stats" => @spotlight_stats.stringify_keys,
        "employee_entry_count" => @employee_entries.size
      }

      notification = @manager_teammate.notifications.create!(
        notification_type: NOTIFICATION_TYPE,
        status: "preparing_to_send",
        metadata: shared_metadata,
        rich_message: message.slack_blocks,
        fallback_text: message.fallback_text
      )

      post_result = slack_service.post_message(notification.id)
      unless post_result[:success]
        return Result.err(post_result[:error].presence || "Slack failed to post the nudge.")
      end

      notification.reload
      post_employee_thread_replies!(
        slack_service: slack_service,
        main_notification: notification,
        shared_metadata: shared_metadata
      )
      post_importance_thread_reply!(
        slack_service: slack_service,
        main_notification: notification,
        shared_metadata: shared_metadata,
        message: message
      )

      Result.ok(notification: notification)
    rescue Slack::Web::Api::Errors::SlackError => e
      Result.err("Slack error: #{e.message}")
    rescue StandardError => e
      Result.err(e.message)
    end

    private

    def post_employee_thread_replies!(slack_service:, main_notification:, shared_metadata:)
      @employee_entries.each do |entry|
        thread_message = EmployeeThreadMessage.new(entry: entry)
        thread_notification = @manager_teammate.notifications.create!(
          notification_type: NOTIFICATION_TYPE,
          main_thread: main_notification,
          status: "preparing_to_send",
          metadata: shared_metadata.merge(
            "employee_teammate_id" => entry[:teammate_id] || entry["teammate_id"],
            "employee_status" => entry[:status] || entry["status"]
          ),
          rich_message: thread_message.slack_blocks,
          fallback_text: thread_message.fallback_text
        )
        slack_service.post_message(thread_notification.id)
      end
    end

    def post_importance_thread_reply!(slack_service:, main_notification:, shared_metadata:, message:)
      return unless message.include_importance_thread?

      thread_notification = @manager_teammate.notifications.create!(
        notification_type: NOTIFICATION_TYPE,
        main_thread: main_notification,
        status: "preparing_to_send",
        metadata: shared_metadata.merge("thread_kind" => "importance"),
        rich_message: message.importance_slack_blocks,
        fallback_text: message.importance_fallback_text
      )
      slack_service.post_message(thread_notification.id)
    end
  end
end
