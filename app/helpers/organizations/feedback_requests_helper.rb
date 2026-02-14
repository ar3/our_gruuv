# frozen_string_literal: true

module Organizations
  module FeedbackRequestsHelper
    FEEDBACK_REQUEST_WIZARD_STEPS = {
      1 => { name: 'Who & Why', path_method: :edit_organization_feedback_request_path },
      2 => { name: 'Select Focus', path_method: :select_focus_organization_feedback_request_path },
      3 => { name: 'Edit Questions', path_method: :feedback_prompt_organization_feedback_request_path },
      4 => { name: 'Select Respondents', path_method: :select_respondents_organization_feedback_request_path }
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
  end
end
