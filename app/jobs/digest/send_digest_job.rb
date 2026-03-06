# frozen_string_literal: true

module Digest
  # Sends the GSD + About Me digest to a teammate's configured channels (Slack now; SMS in Phase 4).
  # Call with teammate_id. For "send now" we send to all channels they have configured (Slack if digest_slack on; SMS if phone + digest_sms on).
  class SendDigestJob < ApplicationJob
    queue_as :default

    def perform(teammate_id)
      teammate = CompanyTeammate.find_by(id: teammate_id)
      return unless teammate
      return unless teammate.organization

      organization = teammate.organization
      person = teammate.person
      prefs = UserPreference.for_person(person)

      send_slack(teammate, organization, prefs) if should_send_slack?(teammate, prefs)
      send_sms(teammate, organization, prefs) if should_send_sms?(person, prefs)
    end

    private

    def should_send_slack?(teammate, prefs)
      return false unless teammate.has_slack_identity? && teammate.slack_user_id.present?
      freq = prefs.effective_digest_slack(teammate)
      freq.present? && freq != 'off'
    end

    # Digest bot name so the message appears in a DM between the user and ourgruuvbot
    DIGEST_BOT_USERNAME = 'ourgruuvbot'

    def send_slack(teammate, organization, prefs)
      return unless organization.calculated_slack_config&.configured?

      slack_service = SlackService.new(organization)
      dm = slack_service.open_dm(user_id: teammate.slack_user_id)
      unless dm[:success] && dm[:channel_id].present?
        Rails.logger.warn "Digest::SendDigestJob: Could not open DM for teammate #{teammate.id}: #{dm[:error]}"
        return
      end

      channel_id = dm[:channel_id]
      digest_metadata = { channel: channel_id, username: DIGEST_BOT_USERNAME }

      builder = SlackMessageBuilderService.new(teammate: teammate, organization: organization)
      main_payload = builder.main_message
      thread1_payload = builder.thread1_gsd_list
      thread2_payload = builder.thread2_about_me

      main_notification = Notification.create!(
        notifiable: teammate,
        notification_type: 'gsd_digest',
        status: 'preparing_to_send',
        metadata: digest_metadata,
        rich_message: main_payload[:blocks],
        fallback_text: main_payload[:text]
      )

      result = slack_service.post_message(main_notification.id)
      unless result[:success] && main_notification.reload.message_id.present?
        Rails.logger.warn "Digest::SendDigestJob: Slack main message failed for teammate #{teammate.id}: #{result[:error]}"
        return
      end

      [thread1_payload, thread2_payload].each do |payload|
        thread_notification = Notification.create!(
          notifiable: teammate,
          notification_type: 'gsd_digest',
          main_thread: main_notification,
          status: 'preparing_to_send',
          metadata: digest_metadata,
          rich_message: payload[:blocks],
          fallback_text: payload[:text]
        )
        slack_service.post_message(thread_notification.id)
      end
    end

    def should_send_sms?(person, prefs)
      return false if person.unique_textable_phone_number.blank?
      freq = prefs.effective_digest_sms(person)
      freq.present? && freq != 'off'
    end

    def send_sms(teammate, organization, prefs)
      person = teammate.person
      return if person.unique_textable_phone_number.blank?

      client_id = ENV['NOTIFICATION_API_CLIENT_ID']
      client_secret = ENV['NOTIFICATION_API_CLIENT_SECRET']
      return if client_id.blank? || client_secret.blank?

      message = SlackMessageBuilderService.new(teammate: teammate, organization: organization).short_summary_for_sms
      service = NotificationApiService.new(client_id: client_id, client_secret: client_secret)
      result = service.send_notification(
        type: 'gsd_digest_sms',
        to: { id: person.email, number: person.unique_textable_phone_number },
        sms: { message: message }
      )
      unless result[:success]
        Rails.logger.warn "Digest::SendDigestJob: SMS failed for teammate #{teammate.id}: #{result[:error]}"
      end
    end
  end
end
