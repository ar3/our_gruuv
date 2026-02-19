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
      requestor_same_as_subject = @feedback_request.requestor_teammate_id == @feedback_request.subject_of_feedback_teammate_id
      subject_name = @feedback_request.subject_of_feedback_teammate&.person&.display_name.presence || 'a colleague'
      subject_casual_name = @feedback_request.subject_of_feedback_teammate&.person&.casual_name.presence || subject_name
      requestor_name = @feedback_request.requestor_teammate&.person&.display_name.presence || 'Someone'
      requestor_slack_user_id = @feedback_request.requestor_teammate&.slack_user_id
      subject_line = @feedback_request.subject_line.presence

      slack_service = SlackService.new(@company)
      sent = 0
      errors = []

      responders_with_slack.each do |responder|
        channel_id = resolve_channel_for_respondent(slack_service, responder, requestor_slack_user_id)

        blocks = build_message_blocks(
          requestor_same_as_subject: requestor_same_as_subject,
          subject_casual_name: subject_casual_name,
          subject_name: subject_name,
          subject_line: subject_line,
          requestor_name: requestor_name,
          answer_url: answer_url
        )
        fallback_text = build_fallback_text(
          requestor_same_as_subject: requestor_same_as_subject,
          subject_casual_name: subject_casual_name,
          subject_name: subject_name,
          subject_line: subject_line,
          answer_url: answer_url
        )

        notification = @feedback_request.notifications.create!(
          notification_type: 'feedback_request',
          status: 'preparing_to_send',
          metadata: { channel: channel_id, teammate_id: responder.id },
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

    # Resolve Slack channel for this respondent: group DM (respondent + requestor) when possible, else 1:1 DM.
    def resolve_channel_for_respondent(slack_service, responder, requestor_slack_user_id)
      user_ids = [responder.slack_user_id, requestor_slack_user_id].compact.uniq
      return responder.slack_user_id if user_ids.size < 2

      result = slack_service.open_or_create_group_dm(user_ids: user_ids)
      result[:success] ? result[:channel_id] : responder.slack_user_id
    end

    def subject_suffix(subject_line)
      subject_line.present? ? " (#{subject_line})" : ""
    end

    def build_message_blocks(requestor_same_as_subject:, subject_casual_name:, subject_name:, subject_line:, requestor_name:, answer_url:)
      suffix = subject_suffix(subject_line)
      text = if requestor_same_as_subject
        "*Feedback request*\n\n#{subject_casual_name}#{suffix} has requested your feedback. " \
          "Please share your input using the link below.\n\n" \
          "<#{answer_url}|Respond to this feedback request>"
      else
        "*Feedback request*\n\n#{requestor_name} has requested your feedback about #{subject_name}#{suffix}. " \
          "Please share your input using the link below.\n\n" \
          "<#{answer_url}|Respond to this feedback request>"
      end
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

    def build_fallback_text(requestor_same_as_subject:, subject_casual_name:, subject_name:, subject_line:, answer_url:)
      suffix = subject_suffix(subject_line)
      if requestor_same_as_subject
        "#{subject_casual_name}#{suffix} has requested your feedback. Respond here: #{answer_url}"
      else
        "You've been asked to give feedback about #{subject_name}#{suffix}. Respond here: #{answer_url}"
      end
    end
  end
end
