FactoryBot.define do
  factory :feedback_request do
    association :company, factory: [:organization, :company]
    association :requestor_teammate, factory: [:company_teammate]
    association :subject_of_feedback_teammate, factory: [:company_teammate]
    subject_line { "Feedback request #{rand(1000)}" }
    deleted_at { nil }

    after(:build) do |feedback_request|
      # Ensure teammates are in the same company
      feedback_request.requestor_teammate.organization = feedback_request.company
      feedback_request.subject_of_feedback_teammate.organization = feedback_request.company
    end

    trait :archived do
      deleted_at { Time.current }
    end

    trait :ready do
      after(:create) do |feedback_request|
        # Create questions and responders to make it ready (not invalid)
        create(:feedback_request_question, feedback_request: feedback_request, question_text: 'Test question?', position: 1)
        responder = create(:company_teammate, organization: feedback_request.company)
        feedback_request.feedback_request_responders.create!(teammate: responder)
      end
    end

    trait :active do
      after(:create) do |feedback_request|
        # Create questions and responders to make it ready
        create(:feedback_request_question, feedback_request: feedback_request, question_text: 'Test question?', position: 1)
        responder = create(:company_teammate, organization: feedback_request.company)
        feedback_request.feedback_request_responders.create!(teammate: responder)
        # Create a notification to mark it as active
        feedback_request.notifications.create!(
          notification_type: 'feedback_request',
          status: 'sent_successfully',
          metadata: {}
        )
      end
    end

    trait :invalid do
      # Invalid by default (no questions or responders)
    end

    trait :with_questions do
      after(:create) do |feedback_request|
        create(:feedback_request_question, feedback_request: feedback_request, position: 1)
        create(:feedback_request_question, :second_question, feedback_request: feedback_request, position: 2)
        create(:feedback_request_question, :third_question, feedback_request: feedback_request, position: 3)
      end
    end

    trait :with_responders do
      after(:create) do |feedback_request|
        responder1 = create(:company_teammate, organization: feedback_request.company)
        responder2 = create(:company_teammate, organization: feedback_request.company)
        feedback_request.feedback_request_responders.create!(teammate: responder1)
        feedback_request.feedback_request_responders.create!(teammate: responder2)
      end
    end
  end
end
