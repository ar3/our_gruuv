# frozen_string_literal: true

module PossibleObservationTranscripts
  class BatchCreateFeedbackRequestsService
    def self.call(transcript:, creator:, impersonating_teammate: nil, extraction_ids:, send_notifications_now: false)
      new(
        transcript: transcript,
        creator: creator,
        impersonating_teammate: impersonating_teammate,
        extraction_ids: extraction_ids,
        send_notifications_now: send_notifications_now
      ).call
    end

    def initialize(transcript:, creator:, impersonating_teammate:, extraction_ids:, send_notifications_now:)
      @transcript = transcript
      @creator = creator
      @impersonating_teammate = impersonating_teammate
      @extraction_ids = Array(extraction_ids).map(&:to_s).reject(&:blank?).to_set
      @send_notifications_now = send_notifications_now
      @company = @transcript.organization.root_company || @transcript.organization
      @pundit_user = OpenStruct.new(user: @creator, impersonating_teammate: @impersonating_teammate)
    end

    def call
      return Result.err('Select at least one extraction.') if @extraction_ids.empty?

      items = @transcript.extraction_items.map(&:to_h)
      errors = []
      notification_errors = []
      created = 0
      notifications_sent = 0
      created_feedback_requests = []

      items.each do |item|
        next unless @extraction_ids.include?(item['id'].to_s)
        next if item['feedback_request_id'].present?

        sid = item['subject_company_teammate_id'].presence&.to_i
        rid = item['responder_company_teammate_id'].presence&.to_i
        if sid.blank? || rid.blank?
          errors << "Row #{item['id']}: choose both subject and responder."
          next
        end

        subject = CompanyTeammate.find_by(id: sid)
        responder = CompanyTeammate.find_by(id: rid)
        unless teammate_in_company_tree?(subject) && teammate_in_company_tree?(responder)
          errors << "Row #{item['id']}: invalid teammate selection."
          next
        end

        subject_line = "Potential Observation from: #{@transcript.display_name}"
        fr = FeedbackRequest.new(
          company: @company,
          subject_of_feedback_teammate: subject,
          subject_line: subject_line,
          possible_observation_transcript: @transcript
        )

        unless FeedbackRequestPolicy.new(@pundit_user, fr).create?
          errors << "Row #{item['id']}: you are not allowed to request feedback for #{subject.person.display_name}."
          next
        end

        position = subject.active_employment_tenure&.position
        question_attrs = [{ 'question_text' => question_text_for(item: item, subject: subject), 'position' => 1 }]
        if position.present?
          question_attrs[0]['rateable_type'] = 'Position'
          question_attrs[0]['rateable_id'] = position.id
        end

        result = FeedbackRequests::CreateService.call(
          feedback_request: fr,
          questions_attributes: question_attrs,
          responder_teammate_ids: [responder.id],
          current_teammate: @creator
        )

        if result.ok?
          item['feedback_request_id'] = result.value.id
          created += 1
          created_feedback_requests << result.value
        else
          errors << "Row #{item['id']}: #{Array(result.error).join(', ')}"
        end
      end

      @transcript.replace_extraction_items!(items.map { |i| i.stringify_keys })

      if @send_notifications_now
        created_feedback_requests.each do |feedback_request|
          notification_result = FeedbackRequests::NotifyRespondentsService.call(feedback_request: feedback_request)
          if notification_result.ok?
            notifications_sent += notification_result.value[:sent].to_i
          else
            notification_errors << "Request ##{feedback_request.id}: #{notification_result.error}"
          end
        end
      end

      Result.ok(
        created: created,
        errors: errors,
        notifications_requested: @send_notifications_now,
        notifications_sent: notifications_sent,
        notification_errors: notification_errors
      )
    end

    private

    def teammate_in_company_tree?(teammate)
      return false unless teammate

      teammate.organization == @company || teammate.organization.root_company == @company
    end

    def question_text_for(item:, subject:)
      transcript_name = @transcript.display_name.to_s
      quote = item['quote'].to_s.strip
      recipient_casual_name = subject&.person&.casual_name.presence || subject&.person&.display_name.presence || 'the teammate'

      <<~TEXT.strip
        From the #{transcript_name} transcript you said:

        #{quote}

        Copy and paste this below and hit send to ensure this feedback is associated with #{recipient_casual_name}.
      TEXT
    end
  end
end
