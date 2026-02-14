# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::FeedbackRequestsHelper, type: :helper do
  let(:company) { create(:organization) }
  let(:requestor_teammate) { create(:company_teammate, organization: company) }
  let(:subject_teammate) { create(:company_teammate, organization: company) }

  describe '#feedback_request_wizard_step_enabled?' do
    context 'when feedback request has only subject and subject_line (no questions)' do
      let(:feedback_request) do
        create(:feedback_request,
          company: company,
          requestor_teammate: requestor_teammate,
          subject_of_feedback_teammate: subject_teammate,
          subject_line: 'Test'
        )
      end

      before { feedback_request.feedback_request_questions.destroy_all }

      it 'enables step 1 (Edit)' do
        expect(helper.feedback_request_wizard_step_enabled?(feedback_request, 1)).to be true
      end

      it 'enables step 2 (Select Focus)' do
        expect(helper.feedback_request_wizard_step_enabled?(feedback_request, 2)).to be true
      end

      it 'disables step 3 (Edit Questions)' do
        expect(helper.feedback_request_wizard_step_enabled?(feedback_request, 3)).to be false
      end

      it 'disables step 4 (Select Respondents)' do
        expect(helper.feedback_request_wizard_step_enabled?(feedback_request, 4)).to be false
      end
    end

    context 'when feedback request has questions with blank question_text' do
      let(:feedback_request) do
        create(:feedback_request,
          company: company,
          requestor_teammate: requestor_teammate,
          subject_of_feedback_teammate: subject_teammate,
          subject_line: 'Test'
        )
      end

      before do
        feedback_request.feedback_request_questions.destroy_all
        create(:feedback_request_question, feedback_request: feedback_request, question_text: '', position: 1)
        feedback_request.reload
      end

      it 'enables steps 1, 2, and 3' do
        expect(helper.feedback_request_wizard_step_enabled?(feedback_request, 1)).to be true
        expect(helper.feedback_request_wizard_step_enabled?(feedback_request, 2)).to be true
        expect(helper.feedback_request_wizard_step_enabled?(feedback_request, 3)).to be true
      end

      it 'disables step 4' do
        expect(helper.feedback_request_wizard_step_enabled?(feedback_request, 4)).to be false
      end
    end

    context 'when feedback request has questions with all question_text filled' do
      let(:feedback_request) do
        create(:feedback_request,
          company: company,
          requestor_teammate: requestor_teammate,
          subject_of_feedback_teammate: subject_teammate,
          subject_line: 'Test'
        )
      end

      before do
        feedback_request.feedback_request_questions.destroy_all
        create(:feedback_request_question, feedback_request: feedback_request, question_text: 'Q1?', position: 1)
        feedback_request.reload
      end

      it 'enables all four steps' do
        expect(helper.feedback_request_wizard_step_enabled?(feedback_request, 1)).to be true
        expect(helper.feedback_request_wizard_step_enabled?(feedback_request, 2)).to be true
        expect(helper.feedback_request_wizard_step_enabled?(feedback_request, 3)).to be true
        expect(helper.feedback_request_wizard_step_enabled?(feedback_request, 4)).to be true
      end
    end

    context 'when feedback request is archived' do
      let(:feedback_request) do
        create(:feedback_request, :archived,
          company: company,
          requestor_teammate: requestor_teammate,
          subject_of_feedback_teammate: subject_teammate,
          subject_line: 'Test'
        )
      end

      it 'enables step 1 when invalid (can_be_edited? is true for invalid archived)' do
        # Model: can_be_edited? = invalid? || ready?; archived has no questions so invalid? is true
        expect(helper.feedback_request_wizard_step_enabled?(feedback_request, 1)).to be true
      end
    end
  end

  describe '#feedback_request_wizard_step_tooltip' do
    let(:feedback_request) do
      create(:feedback_request,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Test'
      )
    end

    before { feedback_request.feedback_request_questions.destroy_all }

    it 'returns nil for enabled steps' do
      expect(helper.feedback_request_wizard_step_tooltip(feedback_request, 1)).to be_nil
      expect(helper.feedback_request_wizard_step_tooltip(feedback_request, 2)).to be_nil
    end

    it 'returns tooltip for disabled step 3 when no questions' do
      expect(helper.feedback_request_wizard_step_tooltip(feedback_request, 3)).to eq(
        'Select at least one focus area in Select Focus first.'
      )
    end

    it 'returns tooltip for disabled step 4 when questions have blank text' do
      create(:feedback_request_question, feedback_request: feedback_request, question_text: '', position: 1)
      expect(helper.feedback_request_wizard_step_tooltip(feedback_request, 4)).to eq(
        'Fill in all question text in Edit Questions first.'
      )
    end
  end

  describe '#feedback_request_wizard_step_name' do
    it 'returns step names for 1–4' do
      expect(helper.feedback_request_wizard_step_name(1)).to eq('Who & Why')
      expect(helper.feedback_request_wizard_step_name(2)).to eq('Select Focus')
      expect(helper.feedback_request_wizard_step_name(3)).to eq('Edit Questions')
      expect(helper.feedback_request_wizard_step_name(4)).to eq('Select Respondents')
    end

    it 'returns fallback for unknown step' do
      expect(helper.feedback_request_wizard_step_name(99)).to eq('Step 99')
    end
  end
end
