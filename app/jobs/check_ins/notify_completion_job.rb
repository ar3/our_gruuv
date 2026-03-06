# frozen_string_literal: true

module CheckIns
  class NotifyCompletionJob < ApplicationJob
    queue_as :default

    def self.perform_and_get_result(check_in_id:, check_in_type:, completion_state:, organization_id:)
      job = new
      job.perform(check_in_id: check_in_id, check_in_type: check_in_type, completion_state: completion_state, organization_id: organization_id)
    end

    def perform(check_in_id:, check_in_type:, completion_state:, organization_id:)
      organization = Organization.find(organization_id)
      check_in = find_check_in(check_in_type, check_in_id)
      return unless check_in

      employee_teammate = check_in.teammate
      employment_tenure = employee_teammate.employment_tenures.active.where(company: organization).first
      manager_teammate = employment_tenure&.manager_teammate
      return unless manager_teammate

      return unless employee_teammate.has_slack_identity? && employee_teammate.slack_user_id.present?
      return unless manager_teammate.has_slack_identity? && manager_teammate.slack_user_id.present?

      action_taker_teammate = resolve_action_taker(check_in, completion_state, employee_teammate, manager_teammate)
      return unless action_taker_teammate

      hour_marker = Time.current.utc.beginning_of_hour
      slack_service = SlackService.new(organization)

      batch = find_or_create_batch(
        organization: organization,
        hour_marker: hour_marker,
        employee_teammate: employee_teammate,
        manager_teammate: manager_teammate,
        action_taker_teammate: action_taker_teammate
      )

      batch.with_lock do
        if batch.notification_id.blank?
          return { success: false, error: 'Failed to create or post main message' } unless create_main_message_and_thread(
            batch: batch,
            slack_service: slack_service,
            organization: organization,
            employee_teammate: employee_teammate,
            manager_teammate: manager_teammate,
            action_taker_teammate: action_taker_teammate,
            hour_marker: hour_marker
          )
        else
          append_to_existing_batch(
            batch: batch,
            slack_service: slack_service,
            organization: organization,
            employee_teammate: employee_teammate,
            manager_teammate: manager_teammate,
            hour_marker: hour_marker
          )
        end
      end

      { success: true }
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Check-in or organization not found: #{e.message}"
      { success: false, error: e.message }
    rescue StandardError => e
      Rails.logger.error "Unexpected error in NotifyCompletionJob: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, error: "Unexpected error: #{e.message}" }
    end

    private

    def find_check_in(check_in_type, check_in_id)
      case check_in_type.to_s
      when 'AssignmentCheckIn'
        AssignmentCheckIn.find(check_in_id)
      when 'PositionCheckIn'
        PositionCheckIn.find(check_in_id)
      when 'AspirationCheckIn'
        AspirationCheckIn.find(check_in_id)
      else
        Rails.logger.error "Unknown check-in type: #{check_in_type}"
        nil
      end
    end

    def resolve_action_taker(check_in, completion_state, employee_teammate, manager_teammate)
      case completion_state.to_sym
      when :employee_only
        employee_teammate
      when :manager_only
        manager_teammate
      when :both_complete
        emp_at = check_in.employee_completed_at
        mgr_at = check_in.manager_completed_at
        if emp_at.present? && mgr_at.present?
          emp_at > mgr_at ? employee_teammate : manager_teammate
        elsif mgr_at.present?
          manager_teammate
        else
          employee_teammate
        end
      else
        Rails.logger.error "Unknown completion state: #{completion_state}"
        nil
      end
    end

    def find_or_create_batch(organization:, hour_marker:, employee_teammate:, manager_teammate:, action_taker_teammate:)
      CheckInCompletionNotificationBatch.find_or_create_by!(
        organization_id: organization.id,
        hour_marker: hour_marker,
        employee_teammate_id: employee_teammate.id,
        manager_teammate_id: manager_teammate.id,
        action_taker_teammate_id: action_taker_teammate.id
      )
    end

    def create_main_message_and_thread(batch:, slack_service:, organization:, employee_teammate:, manager_teammate:, action_taker_teammate:, hour_marker:)
      group_dm_result = slack_service.open_or_create_group_dm(
        user_ids: [employee_teammate.slack_user_id, manager_teammate.slack_user_id]
      )
      unless group_dm_result[:success]
        Rails.logger.error "Failed to open group DM for check-in completion batch: #{group_dm_result[:error]}"
        return false
      end

      channel_id = group_dm_result[:channel_id]
      main_message_text = build_main_message_text(action_taker_teammate, organization, employee_teammate)

      notification = Notification.create!(
        notifiable: batch,
        notification_type: 'check_in_completion',
        status: 'preparing_to_send',
        metadata: { 'channel' => channel_id, 'thread_check_in_keys' => [] },
        fallback_text: main_message_text
      )

      post_result = slack_service.post_group_dm(channel_id: channel_id, text: main_message_text)
      unless post_result[:success]
        Rails.logger.error "Failed to post group DM for check-in completion: #{post_result[:error]}"
        notification.update!(status: 'send_failed')
        return false
      end

      notification.update!(
        message_id: post_result[:message_id],
        status: 'sent_successfully'
      )
      batch.update!(notification_id: notification.id)

      thread_ts = post_result[:message_id]
      active_check_ins = active_check_ins_for_hour(employee_teammate, organization, hour_marker)
      thread_check_in_keys = []
      active_check_ins.each do |check_in|
        key = { 'type' => check_in.class.name, 'id' => check_in.id }
        thread_text = build_thread_message(check_in, employee_teammate, manager_teammate, organization)
        thread_result = slack_service.post_message_to_thread(channel_id: channel_id, thread_ts: thread_ts, text: thread_text)
        thread_check_in_keys << key if thread_result[:success]
      end
      notification.update!(metadata: notification.metadata.merge('thread_check_in_keys' => thread_check_in_keys))
      true
    end

    def append_to_existing_batch(batch:, slack_service:, organization:, employee_teammate:, manager_teammate:, hour_marker:)
      notification = batch.notification
      channel_id = notification.metadata['channel']
      thread_ts = notification.message_id
      return unless channel_id.present? && thread_ts.present?

      thread_check_in_keys = notification.metadata['thread_check_in_keys'] || []
      active_check_ins = active_check_ins_for_hour(employee_teammate, organization, hour_marker)

      active_check_ins.each do |check_in|
        key = { 'type' => check_in.class.name, 'id' => check_in.id }
        next if thread_check_in_keys.any? { |k| k['type'] == key['type'] && k['id'] == key['id'] }

        thread_text = build_thread_message(check_in, employee_teammate, manager_teammate, organization)
        thread_result = slack_service.post_message_to_thread(channel_id: channel_id, thread_ts: thread_ts, text: thread_text)
        thread_check_in_keys << key if thread_result[:success]
      end
      notification.update!(metadata: notification.metadata.merge('thread_check_in_keys' => thread_check_in_keys))

      updated_main_text = "#{notification.fallback_text}\n\nLatest update was #{formatted_latest_update_time(batch.action_taker_teammate)}"
      slack_service.update_group_dm_message(
        channel_id: channel_id,
        message_ts: thread_ts,
        text: updated_main_text
      )
    end

    def build_main_message_text(action_taker_teammate, organization, employee_teammate)
      url_options = Rails.application.routes.default_url_options || {}
      check_ins_url = Rails.application.routes.url_helpers.organization_company_teammate_check_ins_url(
        organization,
        employee_teammate,
        url_options
      )
      casual_name = action_taker_teammate.person.casual_name
      "#{casual_name} has completed a check-in! See the thread for all <#{check_ins_url}|check-ins> waiting for the next step."
    end

    def build_thread_message(check_in, employee_teammate, manager_teammate, organization)
      url_options = Rails.application.routes.default_url_options || {}
      employee_name = employee_teammate.person.casual_name
      manager_name = manager_teammate.person.casual_name
      check_in_name = check_in_display_name(check_in)
      timezone = organization_timezone(organization)
      completed_at = [check_in.employee_completed_at, check_in.manager_completed_at].compact.max
      time_str = completed_at ? completed_at.in_time_zone(timezone).strftime('%b %d, %Y at %-I:%M %p %Z') : ''

      if check_in.employee_completed? && check_in.manager_completed?
        finalization_url = Rails.application.routes.url_helpers.organization_company_teammate_finalization_url(
          organization,
          employee_teammate,
          url_options
        )
        "#{employee_name} and #{manager_name} have both checked in on #{check_in_name} and are ready to <#{finalization_url}|review this together>."
      else
        completer_name = check_in.employee_completed? ? employee_name : manager_name
        waiting_on = check_in.employee_completed? ? manager_name : employee_name
        "#{completer_name} has checked in on #{check_in_name} at #{time_str} and is waiting on #{waiting_on}."
      end
    end

    def check_in_display_name(check_in)
      case check_in
      when AssignmentCheckIn
        check_in.assignment.display_name
      when PositionCheckIn
        check_in.employment_tenure.position.display_name
      when AspirationCheckIn
        check_in.aspiration.name
      else
        'check-in'
      end
    end

    def formatted_latest_update_time(action_taker_teammate)
      timezone = action_taker_teammate.person.timezone_or_default
      Time.current.in_time_zone(timezone).strftime('%b %d, %Y at %-I:%M %p %Z')
    end

    def organization_timezone(organization)
      return 'Eastern Time (US & Canada)' unless organization.respond_to?(:default_timezone)
      organization.default_timezone.presence || 'Eastern Time (US & Canada)'
    end

    def active_check_ins_for_hour(employee_teammate, organization, hour_marker)
      hour_end = hour_marker + 1.hour
      args = [hour_marker, hour_end]

      assignment_check_ins = AssignmentCheckIn.joins(:assignment)
        .where(assignments: { company_id: organization.id })
        .where(teammate_id: employee_teammate.id)
        .where("assignment_check_ins.updated_at >= ? AND assignment_check_ins.updated_at < ? AND (assignment_check_ins.employee_completed_at IS NOT NULL OR assignment_check_ins.manager_completed_at IS NOT NULL)", *args)

      position_check_ins = PositionCheckIn.joins(:employment_tenure)
        .where(employment_tenures: { company_id: organization.id, teammate_id: employee_teammate.id })
        .where("position_check_ins.updated_at >= ? AND position_check_ins.updated_at < ? AND (position_check_ins.employee_completed_at IS NOT NULL OR position_check_ins.manager_completed_at IS NOT NULL)", *args)

      aspiration_check_ins = AspirationCheckIn.joins(:aspiration)
        .where(aspirations: { company_id: organization.id })
        .where(teammate_id: employee_teammate.id)
        .where("aspiration_check_ins.updated_at >= ? AND aspiration_check_ins.updated_at < ? AND (aspiration_check_ins.employee_completed_at IS NOT NULL OR aspiration_check_ins.manager_completed_at IS NOT NULL)", *args)

      all = assignment_check_ins.to_a + position_check_ins.to_a + aspiration_check_ins.to_a
      all.uniq.sort_by { |c| c.updated_at }.reverse
    end
  end
end
