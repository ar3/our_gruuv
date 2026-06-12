# frozen_string_literal: true

module Digest
  # Sends the Interesting Things digest as a DM from the OG slack bot (and optional SMS).
  # Only sends when there is at least one interesting thing since the teammate's last
  # visit to the Something Interesting page (or the past 7 days if never visited).
  class SendInterestingThingsJob < ApplicationJob
    include SendsDigestSms

    queue_as :default

    DIGEST_BOT_USERNAME = 'ourgruuvbot'

    def perform(teammate_id)
      teammate = CompanyTeammate.find_by(id: teammate_id)
      return unless teammate
      return unless teammate.organization

      organization = teammate.organization
      person = teammate.person
      prefs = UserPreference.for_person(person)

      since = SomethingInterestingQueryService.baseline(teammate)
      builder = InterestingThingsMessageBuilderService.new(
        teammate: teammate,
        organization: organization,
        since: since
      )
      return if builder.total_count.zero?

      send_slack(teammate, organization, builder) if slack_deliverable?(teammate, organization)
      send_digest_sms(person, prefs, type: 'interesting_things_digest_sms') { builder.short_summary_for_sms }
    end

    private

    def slack_deliverable?(teammate, organization)
      teammate.has_slack_identity? &&
        teammate.slack_user_id.present? &&
        organization.calculated_slack_config&.configured?
    end

    def send_slack(teammate, organization, builder)
      slack_service = SlackService.new(organization)
      dm = slack_service.open_dm(user_id: teammate.slack_user_id)
      unless dm[:success] && dm[:channel_id].present?
        Rails.logger.warn "Digest::SendInterestingThingsJob: Could not open DM for teammate #{teammate.id}: #{dm[:error]}"
        return
      end

      digest_metadata = { channel: dm[:channel_id], username: DIGEST_BOT_USERNAME }
      main_payload = builder.main_message

      main_notification = Notification.create!(
        notifiable: teammate,
        notification_type: 'interesting_things_digest',
        status: 'preparing_to_send',
        metadata: digest_metadata,
        rich_message: main_payload[:blocks],
        fallback_text: main_payload[:text]
      )

      result = slack_service.post_message(main_notification.id)
      unless result[:success] && main_notification.reload.message_id.present?
        Rails.logger.warn "Digest::SendInterestingThingsJob: Slack main message failed for teammate #{teammate.id}: #{result[:error]}"
        return
      end

      builder.thread_payloads.each do |payload|
        thread_notification = Notification.create!(
          notifiable: teammate,
          notification_type: 'interesting_things_digest',
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
