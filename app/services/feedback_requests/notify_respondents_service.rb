module FeedbackRequests
  class NotifyRespondentsService
    def self.call(feedback_request:)
      new(feedback_request: feedback_request).call
    end

    def initialize(feedback_request:)
      @feedback_request = feedback_request
      @company = feedback_request.company
    end

    def call
      return Result.err('Slack is not configured') unless @company.slack_configured?

      responders_with_slack = @feedback_request.responders.select { |r| r.slack_user_id.present? }
      return Result.ok(sent: 0) if responders_with_slack.empty?

      answer_url = Rails.application.routes.url_helpers.answer_organization_feedback_request_url(
        @company,
        @feedback_request
      )
      subject_name = @feedback_request.subject_of_feedback_teammate&.person&.display_name.presence || 'a colleague'
      requestor_name = @feedback_request.requestor_teammate&.person&.display_name.presence || 'Someone'

      slack_service = SlackService.new(@company)
      sent = 0
      errors = []

      responders_with_slack.each do |responder|
        blocks = build_message_blocks(
          subject_name: subject_name,
          requestor_name: requestor_name,
          answer_url: answer_url
        )
        fallback_text = "You've been asked to give feedback about #{subject_name}. Respond here: #{answer_url}"

        notification = @feedback_request.notifications.create!(
          notification_type: 'feedback_request',
          status: 'preparing_to_send',
          metadata: { channel: responder.slack_user_id },
          rich_message: blocks,
          fallback_text: fallback_text
        )

        result = slack_service.post_message(notification.id)
        if result[:success]
          sent += 1
        else
          errors << "#{responder.person.display_name}: #{result[:error]}"
        end
      end

      if errors.any?
        Result.err(errors.join('; '))
      else
        Result.ok(sent: sent)
      end
    rescue Slack::Web::Api::Errors::SlackError => e
      Result.err("Slack API error: #{e.message}")
    rescue StandardError => e
      Result.err("Unexpected error: #{e.message}")
    end

    private

    def build_message_blocks(subject_name:, requestor_name:, answer_url:)
      text = "*Feedback request*\n\n#{requestor_name} has requested your feedback about #{subject_name}. " \
             "Please share your input using the link below.\n\n" \
             "<#{answer_url}|Respond to this feedback request>"
      [
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: text
          }
        }
      ]
    end
  end
end
