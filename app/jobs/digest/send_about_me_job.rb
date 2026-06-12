# frozen_string_literal: true

module Digest
  class SendAboutMeJob < ApplicationJob
    include SlackWeeklyDigestChannel
    include SendsDigestSms

    queue_as :default

    def perform(teammate_id, week_key = nil)
      teammate = CompanyTeammate.find_by(id: teammate_id)
      return unless teammate&.organization

      builder = Digest::SlackMessageBuilderService.new(teammate: teammate, organization: teammate.organization)
      send_slack(teammate, builder)
      send_digest_sms(teammate.person, UserPreference.for_person(teammate.person), type: 'about_me_digest_sms') do
        builder.about_me_short_summary_for_sms
      end

      return if week_key.blank?

      UserPreference.for_person(teammate.person).update_preference('about_me_last_sent_week', week_key)
    end

    private

    def send_slack(teammate, builder)
      channel = open_weekly_digest_slack_channel(teammate)
      return unless channel

      slack_service = channel[:slack_service]
      digest_metadata = channel[:digest_metadata]
      main_payload = builder.about_me_main_payload
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
    end
  end
end
