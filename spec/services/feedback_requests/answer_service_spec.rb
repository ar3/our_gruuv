# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeedbackRequests::AnswerService, type: :service do
  let(:company) { create(:organization) }
  let(:requestor) { create(:company_teammate, organization: company) }
  let(:subject_teammate) { create(:company_teammate, organization: company) }
  let(:responder) { create(:company_teammate, organization: company) }

  let(:feedback_request) do
    create(:feedback_request,
      company: company,
      requestor_teammate: requestor,
      subject_of_feedback_teammate: subject_teammate,
      subject_line: 'Test'
    )
  end

  let(:question_with_rateable) do
    create(:feedback_request_question,
      feedback_request: feedback_request,
      question_text: 'How did they do?',
      position: 1,
      rateable: create(:assignment, company: company)
    )
  end

  let(:question_without_rateable) do
    create(:feedback_request_question,
      feedback_request: feedback_request,
      question_text: 'Any comments?',
      position: 2
    )
  end

  describe '#call' do
    context 'when answer has story only' do
      it 'creates one observation with story as draft (not published)' do
        question_with_rateable
        answers = {
          question_with_rateable.id.to_s => {
            story: 'They did great.',
            rating: 'na',
            privacy_level: 'observed_and_managers'
          }
        }

        expect {
          described_class.call(
            feedback_request: feedback_request,
            answers: answers,
            responder_teammate: responder,
            privacy_level: 'observed_and_managers',
            complete: false
          )
        }.to change { Observation.count }.by(1)

        obs = Observation.last
        expect(obs.story).to eq('They did great.')
        expect(obs.observation_ratings.count).to eq(1)
        expect(obs.observation_ratings.first.rating).to eq('na')
        expect(obs).not_to be_published
      end

      it 'publishes observation when complete: true' do
        question_with_rateable
        answers = {
          question_with_rateable.id.to_s => {
            story: 'They did great.',
            rating: 'na',
            privacy_level: 'observed_and_managers'
          }
        }

        described_class.call(
          feedback_request: feedback_request,
          answers: answers,
          responder_teammate: responder,
          privacy_level: 'observed_and_managers',
          complete: true
        )
        obs = Observation.last
        expect(obs).to be_published
      end
    end

    context 'when answer has rating only (no story)' do
      it 'creates one observation with default story and rating as draft' do
        question_with_rateable
        answers = {
          question_with_rateable.id.to_s => {
            story: '',
            rating: 'agree',
            privacy_level: 'observed_and_managers'
          }
        }

        expect {
          described_class.call(
            feedback_request: feedback_request,
            answers: answers,
            responder_teammate: responder,
            privacy_level: 'observed_and_managers',
            complete: false
          )
        }.to change { Observation.count }.by(1)

        obs = Observation.last
        expect(obs.story).to include('My experience is that')
        expect(obs.story).to include('has shown a agree example of')
        expect(obs.observation_ratings.count).to eq(1)
        expect(obs.observation_ratings.first.rating).to eq('agree')
        expect(obs).not_to be_published
      end

      it 'publishes observation when complete: true' do
        question_with_rateable
        answers = {
          question_with_rateable.id.to_s => {
            story: '',
            rating: 'agree',
            privacy_level: 'observed_and_managers'
          }
        }

        described_class.call(
          feedback_request: feedback_request,
          answers: answers,
          responder_teammate: responder,
          privacy_level: 'observed_and_managers',
          complete: true
        )
        obs = Observation.last
        expect(obs).to be_published
      end
    end

    context 'when answer has neither story nor meaningful rating' do
      it 'does not create an observation' do
        question_with_rateable
        answers = {
          question_with_rateable.id.to_s => {
            story: '',
            rating: 'na',
            privacy_level: 'observed_and_managers'
          }
        }

        expect {
          described_class.call(
            feedback_request: feedback_request,
            answers: answers,
            responder_teammate: responder,
            privacy_level: 'observed_and_managers'
          )
        }.not_to change { Observation.count }
      end
    end

    context 'when multiple questions with mixed content' do
      it 'creates observations only for questions with story or rating' do
        question_with_rateable
        question_without_rateable
        answers = {
          question_with_rateable.id.to_s => { story: 'Yes', rating: 'na', privacy_level: 'observed_and_managers' },
          question_without_rateable.id.to_s => { story: '', rating: 'na', privacy_level: 'observed_and_managers' }
        }

        expect {
          described_class.call(
            feedback_request: feedback_request,
            answers: answers,
            responder_teammate: responder,
            privacy_level: 'observed_and_managers'
          )
        }.to change { Observation.count }.by(1)
      end
    end

    context 'when an observation already exists for the question from this responder' do
      it 'updates the existing observation instead of creating a new one' do
        question_with_rateable
        feedback_request.feedback_request_responders.find_or_create_by!(teammate_id: responder.id)
        existing = nil
        described_class.call(
          feedback_request: feedback_request,
          answers: {
            question_with_rateable.id.to_s => {
              story: 'Original story.',
              rating: 'agree',
              privacy_level: 'observed_and_managers'
            }
          },
          responder_teammate: responder,
          privacy_level: 'observed_and_managers'
        )
        existing = Observation.find_by(feedback_request_question_id: question_with_rateable.id, observer_id: responder.person_id)
        expect(existing).to be_present
        expect(existing.story).to eq('Original story.')
        expect(existing.observation_ratings.find_by(rateable: question_with_rateable.rateable).rating).to eq('agree')

        expect {
          described_class.call(
            feedback_request: feedback_request,
            answers: {
              question_with_rateable.id.to_s => {
                story: 'Updated story.',
                rating: 'strongly_agree',
                privacy_level: 'observed_and_managers'
              }
            },
            responder_teammate: responder,
            privacy_level: 'observed_and_managers'
          )
        }.not_to change { Observation.count }

        existing.reload
        expect(existing.story).to eq('Updated story.')
        expect(existing.observation_ratings.find_by(rateable: question_with_rateable.rateable).rating).to eq('strongly_agree')
      end
    end

    context 'when answers have different privacy_level per question' do
      it 'persists each observation with its chosen privacy_level' do
        question_with_rateable
        question_without_rateable
        answers = {
          question_with_rateable.id.to_s => {
            story: 'Story 1',
            rating: 'na',
            privacy_level: 'observed_only'
          },
          question_without_rateable.id.to_s => {
            story: 'Story 2',
            privacy_level: 'managers_only'
          }
        }

        described_class.call(
          feedback_request: feedback_request,
          answers: answers,
          responder_teammate: responder,
          privacy_level: 'observed_and_managers',
          complete: false
        )

        obs1 = Observation.find_by(feedback_request_question_id: question_with_rateable.id, observer_id: responder.person_id)
        obs2 = Observation.find_by(feedback_request_question_id: question_without_rateable.id, observer_id: responder.person_id)
        expect(obs1.privacy_level).to eq('observed_only')
        expect(obs2.privacy_level).to eq('managers_only')
      end
    end
  end
end
