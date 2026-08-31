# frozen_string_literal: true

module Organizations
  module FeedbackRequestsHelper
    FEEDBACK_REQUEST_WIZARD_STEPS = {
      1 => { name: 'Who & Why', path_method: :edit_organization_feedback_request_path },
      2 => { name: 'Select Focus', path_method: :select_focus_organization_feedback_request_path },
      3 => { name: 'Edit Questions', path_method: :feedback_prompt_organization_feedback_request_path },
      4 => { name: 'Who Can Respond', path_method: :select_respondents_organization_feedback_request_path }
    }.freeze

    def feedback_request_wizard_step_enabled?(feedback_request, step)
      case step
      when 1
        feedback_request.can_be_edited?
      when 2
        feedback_request.subject_of_feedback_teammate_id.present? && feedback_request.subject_line.present?
      when 3
        feedback_request.feedback_request_questions.any?
      when 4
        feedback_request.feedback_request_questions.any? &&
          feedback_request.feedback_request_questions.none? { |q| q.question_text.blank? }
      else
        false
      end
    end

    def feedback_request_wizard_step_tooltip(feedback_request, step)
      return nil if feedback_request_wizard_step_enabled?(feedback_request, step)

      case step
      when 2
        'Complete subject and subject line in Who & Why first.'
      when 3
        'Select at least one focus area in Select Focus first.'
      when 4
        'Fill in all question text in Edit Questions first.'
      else
        nil
      end
    end

    def feedback_request_wizard_step_name(step)
      FEEDBACK_REQUEST_WIZARD_STEPS.fetch(step, {})[:name] || "Step #{step}"
    end

    def feedback_request_open_to_anyone_label(feedback_request)
      feedback_request.open_to_anyone? ? 'Open to anyone with the link' : 'Named respondents only'
    end

    # Explains why the request is in its current derived state (invalid/ready/active/archived).
    # Ready vs Active is about Slack nudges, not whether the answer link works.
    def feedback_request_state_tooltip(feedback_request)
      case feedback_request.state
      when 'invalid'
        reasons = []
        reasons << 'add at least one question' if feedback_request.feedback_request_questions.empty?
        if feedback_request.feedback_request_questions.any? { |q| q.question_text.blank? }
          reasons << 'fill in every question'
        end
        if feedback_request.requires_named_responders? && feedback_request.responders.empty?
          reasons << 'choose at least one named respondent'
        end
        reasons.any? ? "Not ready yet — #{reasons.to_sentence}." : 'This request is incomplete.'
      when 'ready'
        'Valid and answerable. Respondents have not been nudged via Slack yet (open-link sharing still works).'
      when 'active'
        'Valid and answerable. At least one Slack nudge has been sent to respondents.'
      when 'archived'
        'Archived — no longer accepting answers.'
      else
        nil
      end
    end

    def feedback_request_suggested_share_message(feedback_request, answer_url)
      subject_name = feedback_request.subject_of_feedback_teammate&.person&.casual_name.presence || 'them'
      subject_line = feedback_request.subject_line.presence || 'this work'
      <<~MSG.strip
        Could you share quick feedback on #{subject_line}? It goes to #{subject_name} in OurGruuv as an observation.

        #{answer_url}
      MSG
    end

    # One row per submission batch so multiple answers from the same person each appear.
    # Published answers in the same minute are treated as one complete submission.
    ResponderSubmissionRow = Struct.new(
      :responder,
      :responder_record,
      :completed_at,
      :observations_by_question_id,
      :incomplete,
      keyword_init: true
    )

    def feedback_request_responder_submission_rows(responders:, observations:, responder_records_by_teammate_id:)
      rows = []
      responders.each do |responder|
        record = responder_records_by_teammate_id[responder.id]
        person_observations = observations.select { |o| o.observer_id == responder.person_id }
        published = person_observations.select(&:published?)
        drafts = person_observations.reject(&:published?)

        published
          .group_by { |o| o.published_at.to_i / 60 }
          .sort_by { |minute, _| -minute }
          .each do |_minute, batch|
            rows << ResponderSubmissionRow.new(
              responder: responder,
              responder_record: record,
              completed_at: batch.map(&:published_at).compact.min,
              observations_by_question_id: batch.group_by(&:feedback_request_question_id),
              incomplete: false
            )
          end

        if drafts.any?
          rows << ResponderSubmissionRow.new(
            responder: responder,
            responder_record: record,
            completed_at: nil,
            observations_by_question_id: drafts.group_by(&:feedback_request_question_id),
            incomplete: true
          )
        elsif published.empty?
          rows << ResponderSubmissionRow.new(
            responder: responder,
            responder_record: record,
            completed_at: record&.completed_at,
            observations_by_question_id: {},
            incomplete: record&.completed_at.blank?
          )
        end
      end
      rows
    end

    # Display labels used on the answer page instead of enum values (strongly_agree, etc.)
    def observation_rating_display_label(rating)
      return ObservationRating.display_label('na') if rating.blank?

      ObservationRating.display_label(rating)
    end
  end
end
