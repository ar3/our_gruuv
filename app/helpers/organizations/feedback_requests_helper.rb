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

    def feedback_request_suggested_share_message(feedback_request, answer_url)
      subject_name = feedback_request.subject_of_feedback_teammate&.person&.casual_name.presence || 'them'
      subject_line = feedback_request.subject_line.presence || 'this work'
      <<~MSG.strip
        Could you share quick feedback on #{subject_line}? It goes to #{subject_name} in OurGruuv as an observation.

        #{answer_url}
      MSG
    end

    # Display labels used on the answer page instead of enum values (strongly_agree, etc.)
    def observation_rating_display_label(rating)
      return ObservationRating.display_label('na') if rating.blank?

      ObservationRating.display_label(rating)
    end
  end
end
