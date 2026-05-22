# frozen_string_literal: true

module Digest
  class SendOneOnOneDigestJob < ApplicationJob
    include SlackWeeklyDigestChannel

    queue_as :default

    def perform(teammate_id, week_key = nil)
      teammate = CompanyTeammate.find_by(id: teammate_id)
      channel = open_weekly_digest_slack_channel(teammate)
      return unless channel

      Digest::SyncOneOnOneAsanaForAboutMe.call(
        employee_teammate: teammate,
        manager_teammate: channel[:manager_teammate]
      )

      slack_service = channel[:slack_service]
      digest_metadata = channel[:digest_metadata]
      builder = Digest::SlackMessageBuilderService.new(teammate: teammate, organization: teammate.organization)
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
      return unless result[:success] && main_notification.reload.message_id.present?

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

      return if week_key.blank?

      UserPreference.for_person(teammate.person).update_preference('one_on_one_last_sent_week', week_key)
    end
  end
end
