# frozen_string_literal: true

module Digest
  class SendOneOnOneDigestJob < ApplicationJob
    include SlackWeeklyDigestChannel
    include SendsDigestSms

    queue_as :default

    def perform(teammate_id, week_key = nil)
      teammate = CompanyTeammate.find_by(id: teammate_id)
      unless teammate&.organization
        Rails.logger.warn "Digest::SendOneOnOneDigestJob: teammate #{teammate_id} not found"
        return
      end

      builder = Digest::SlackMessageBuilderService.new(teammate: teammate, organization: teammate.organization)
      send_slack(teammate, builder)
      send_digest_sms(teammate.person, UserPreference.for_person(teammate.person), type: 'one_on_one_digest_sms') do
        builder.one_on_one_short_summary_for_sms
      end

      return if week_key.blank?

      UserPreference.for_person(teammate.person).update_preference('one_on_one_last_sent_week', week_key)
    end

    private

    def send_slack(teammate, builder)
      channel = open_weekly_digest_slack_channel(teammate)
      unless channel
        Rails.logger.warn "Digest::SendOneOnOneDigestJob: could not open Slack channel for teammate #{teammate.id}"
        return
      end

      Digest::SyncOneOnOneAsanaForAboutMe.call(
        employee_teammate: teammate,
        manager_teammate: channel[:manager_teammate]
      )

      slack_service = channel[:slack_service]
      digest_metadata = channel[:digest_metadata]
      main_payload = builder.one_on_one_main_payload
      thread_payload = builder.one_on_one_thread_payload

      main_notification = Notification.create!(
        notifiable: teammate,
        notification_type: 'one_on_one_digest',
        status: 'preparing_to_send',
        metadata: digest_metadata,
        rich_message: main_payload[:blocks],
        fallback_text: main_payload[:text]
      )

      result = slack_service.post_message(main_notification.id)
      unless result[:success] && main_notification.reload.message_id.present?
        Rails.logger.warn(
          "Digest::SendOneOnOneDigestJob: main Slack post failed for teammate #{teammate.id}: #{result[:error]}"
        )
        return
      end

      thread_notification = Notification.create!(
        notifiable: teammate,
        notification_type: 'one_on_one_digest',
        main_thread: main_notification,
        status: 'preparing_to_send',
        metadata: digest_metadata,
        rich_message: thread_payload[:blocks],
        fallback_text: thread_payload[:text]
      )
      slack_service.post_message(thread_notification.id)
    end
  end
end
