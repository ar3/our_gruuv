# frozen_string_literal: true

module Digest
  # Sends the GSD + About Me digest to a teammate's configured channels.
  # Call with teammate_id. "On" means enabled medium.
  class SendDigestJob < ApplicationJob
    include SendsDigestSms

    queue_as :default

    def perform(teammate_id)
      teammate = CompanyTeammate.find_by(id: teammate_id)
      return unless teammate
      return unless teammate.organization

      organization = teammate.organization
      person = teammate.person
      prefs = UserPreference.for_person(person)

      send_slack(teammate, organization, prefs) if should_send_slack?(teammate)
      send_digest_sms(person, prefs, type: 'gsd_digest_sms') do
        SlackMessageBuilderService.new(teammate: teammate, organization: organization).short_summary_for_sms
      end
    end

    private

    # Slack is the always-on channel; deliverability only depends on a connected identity.
    def should_send_slack?(teammate)
      teammate.has_slack_identity? && teammate.slack_user_id.present?
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
      gsd_thread_payloads = builder.gsd_thread_payloads

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

      gsd_thread_payloads.each do |payload|
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

  end
end
