# frozen_string_literal: true

module Digest
  class SendAboutMeJob < ApplicationJob
    queue_as :default

    ABOUT_ME_BOT_USERNAME = 'ourgruuvbot'

    def perform(teammate_id, week_key = nil)
      teammate = CompanyTeammate.find_by(id: teammate_id)
      return unless teammate&.organization

      manager_teammate = teammate.active_employment_tenure&.manager_teammate
      employee_slack_enabled = UserPreference.for_person(teammate.person).effective_digest_slack(nil) == 'on'
      manager_slack_enabled = manager_teammate.present? && UserPreference.for_person(manager_teammate.person).effective_digest_slack(nil) == 'on'
      return unless employee_slack_enabled || manager_slack_enabled

      user_ids = []
      if teammate.has_slack_identity? && teammate.slack_user_id.present?
        user_ids << teammate.slack_user_id
      end
      if manager_teammate&.has_slack_identity? && manager_teammate.slack_user_id.present?
        user_ids << manager_teammate.slack_user_id
      end
      user_ids.uniq!
      return if user_ids.empty?

      organization = teammate.organization
      return unless organization.calculated_slack_config&.configured?

      slack_service = SlackService.new(organization)
      dm = user_ids.one? ? slack_service.open_dm(user_id: user_ids.first) : slack_service.open_or_create_group_dm(user_ids: user_ids)
      return unless dm[:success] && dm[:channel_id].present?

      digest_metadata = { channel: dm[:channel_id], username: ABOUT_ME_BOT_USERNAME }
      builder = Digest::SlackMessageBuilderService.new(teammate: teammate, organization: organization)
      main_payload = builder.about_me_main_payload
      priorities_payload = builder.about_me_priorities_thread_payload
      detail_payload = builder.about_me_thread_payload

      main_notification = Notification.create!(
        notifiable: teammate,
        notification_type: 'about_me_digest',
        status: 'preparing_to_send',
        metadata: digest_metadata,
        rich_message: main_payload[:blocks],
        fallback_text: main_payload[:text]
      )

      result = slack_service.post_message(main_notification.id)
      return unless result[:success] && main_notification.reload.message_id.present?

      priorities_thread_notification = Notification.create!(
        notifiable: teammate,
        notification_type: 'about_me_digest',
        main_thread: main_notification,
        status: 'preparing_to_send',
        metadata: digest_metadata,
        rich_message: priorities_payload[:blocks],
        fallback_text: priorities_payload[:text]
      )
      slack_service.post_message(priorities_thread_notification.id)

      detail_thread_notification = Notification.create!(
        notifiable: teammate,
        notification_type: 'about_me_digest',
        main_thread: main_notification,
        status: 'preparing_to_send',
        metadata: digest_metadata,
        rich_message: detail_payload[:blocks],
        fallback_text: detail_payload[:text]
      )
      slack_service.post_message(detail_thread_notification.id)

      return if week_key.blank?

      UserPreference.for_person(teammate.person).update_preference('about_me_last_sent_week', week_key)
    end
  end
end
