module FeedbackRequests
  class AnswerService
    def self.call(feedback_request:, answers:, responder_teammate:, privacy_level: 'observed_and_managers')
      new(
        feedback_request: feedback_request,
        answers: answers,
        responder_teammate: responder_teammate,
        privacy_level: privacy_level
      ).call
    end

    def initialize(feedback_request:, answers:, responder_teammate:, privacy_level: 'observed_and_managers')
      @feedback_request = feedback_request
      @answers = answers || {}
      @responder_teammate = responder_teammate
      @privacy_level = privacy_level
    end

    def call
      ApplicationRecord.transaction do
        created_observations = []

        # Create one observation per answered question
        @feedback_request.feedback_request_questions.ordered.each do |question|
          answer_data = @answers[question.id.to_s] || @answers[question.id]
          next unless answer_data && answer_data[:story].present?

          # Create observation
          observation = Observation.new(
            observer: @responder_teammate.person,
            company: @feedback_request.company,
            story: answer_data[:story],
            feedback_request_question: question,
            privacy_level: answer_data[:privacy_level] || @privacy_level,
            observed_at: Time.current
          )

          # Add subject as observee
          observation.observees.build(teammate: @feedback_request.subject_of_feedback_teammate)

          unless observation.save
            return Result.err(observation.errors.full_messages)
          end

          # Add resource rating if question has a rateable
          if question.rateable.present?
            observation.observation_ratings.build(
              rateable: question.rateable,
              rating: answer_data[:rating] || answer_data[:assignment_rating] || answer_data[:ability_rating] || answer_data[:aspiration_rating] || 'na'
            )
          end

          # Add optional ratings for questions without rateable
          if question.rateable.blank? && answer_data[:ratings]
            answer_data[:ratings].each do |rating_data|
              next unless rating_data[:rateable_type].present? && rating_data[:rateable_id].present?
              observation.observation_ratings.build(
                rateable_type: rating_data[:rateable_type],
                rateable_id: rating_data[:rateable_id],
                rating: rating_data[:rating] || 'na'
              )
            end
          end

          # Save ratings
          observation.observation_ratings.each do |rating|
            unless rating.save
              return Result.err(rating.errors.full_messages)
            end
          end

          created_observations << observation
        end

        Result.ok(created_observations)
      end
    rescue => e
      Rails.logger.error "Failed to create observations from feedback request: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      Result.err("Failed to create observations: #{e.message}")
    end
  end
end
