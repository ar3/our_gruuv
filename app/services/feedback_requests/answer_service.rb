module FeedbackRequests
  class AnswerService
    def self.call(feedback_request:, answers:, responder_teammate:, privacy_level: 'observed_and_managers', complete: false)
      new(
        feedback_request: feedback_request,
        answers: answers,
        responder_teammate: responder_teammate,
        privacy_level: privacy_level,
        complete: complete
      ).call
    end

    def initialize(feedback_request:, answers:, responder_teammate:, privacy_level: 'observed_and_managers', complete: false)
      @feedback_request = feedback_request
      @answers = answers || {}
      @responder_teammate = responder_teammate
      @privacy_level = privacy_level
      @complete = complete
    end

    def call
      ApplicationRecord.transaction do
        created_or_updated = []

        @feedback_request.feedback_request_questions.ordered.each do |question|
          answer_data = @answers[question.id.to_s] || @answers[question.id]
          next unless has_story_or_rating?(answer_data)

          raw_story = fetch_val(answer_data, :story).to_s.presence.to_s
          rating = normalize_rating(fetch_val(answer_data, :rating))
          story = raw_story.presence || default_story_for_rating_only(question, rating)
          privacy_level = fetch_val(answer_data, :privacy_level).presence || @privacy_level

          observation = Observation.find_by(
            feedback_request_question_id: question.id,
            observer_id: @responder_teammate.person_id
          )

          if observation
            observation.assign_attributes(story: story, privacy_level: privacy_level)
            unless observation.save
              return Result.err(observation.errors.full_messages)
            end

            if question.rateable.present?
              obs_rating = observation.observation_ratings.find_by(rateable: question.rateable)
              if obs_rating
                obs_rating.update!(rating: rating) unless obs_rating.rating == rating
              else
                observation.observation_ratings.create!(rateable: question.rateable, rating: rating)
              end
            end

            if question.rateable.blank? && fetch_val(answer_data, :ratings).present?
              Array(fetch_val(answer_data, :ratings)).each do |rating_data|
                rt = fetch_val(rating_data, :rateable_type)
                rid = fetch_val(rating_data, :rateable_id)
                next unless rt.present? && rid.present?
                observation.observation_ratings.find_or_initialize_by(rateable_type: rt, rateable_id: rid).tap do |r|
                  r.rating = fetch_val(rating_data, :rating).presence || 'na'
                  r.save!
                end
              end
            end

            created_or_updated << observation
          else
            observation = Observation.new(
              observer: @responder_teammate.person,
              company: @feedback_request.company,
              story: story,
              feedback_request_question: question,
              privacy_level: privacy_level,
              observed_at: Time.current
            )
            observation.observees.build(teammate: @feedback_request.subject_of_feedback_teammate)

            unless observation.save
              return Result.err(observation.errors.full_messages)
            end

            if question.rateable.present?
              observation.observation_ratings.build(
                rateable: question.rateable,
                rating: rating
              )
            end

            if question.rateable.blank? && fetch_val(answer_data, :ratings).present?
              Array(fetch_val(answer_data, :ratings)).each do |rating_data|
                rt = fetch_val(rating_data, :rateable_type)
                rid = fetch_val(rating_data, :rateable_id)
                next unless rt.present? && rid.present?
                observation.observation_ratings.build(
                  rateable_type: rt,
                  rateable_id: rid,
                  rating: fetch_val(rating_data, :rating).presence || 'na'
                )
              end
            end

            observation.observation_ratings.each do |r|
              unless r.save
                return Result.err(r.errors.full_messages)
              end
            end

            created_or_updated << observation
          end
        end

        if @complete
          created_or_updated.each { |obs| obs.publish! if obs.story.present? }
        end

        Result.ok(created_or_updated)
      end
    rescue => e
      Rails.logger.error "Failed to create observations from feedback request: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      Result.err("Failed to create observations: #{e.message}")
    end

    private

    def has_story_or_rating?(answer_data)
      return false unless answer_data.respond_to?(:key?) && answer_data.respond_to?(:[])

      story_present = fetch_val(answer_data, :story).to_s.present?
      rating_val = fetch_val(answer_data, :rating)
      rating_present = rating_val.present? && rating_val.to_s != 'na'

      story_present || rating_present
    end

    def fetch_val(data, key)
      return nil unless data.respond_to?(:[])
      data[key] || data[key.to_s]
    end

    def normalize_rating(value)
      return 'na' if value.blank?
      value.to_s == 'na' ? 'na' : value.to_s
    end

    def default_story_for_rating_only(question, rating)
      return '' if rating.blank? || rating == 'na'

      question_text = question.question_text.presence || question.prompt_default_text.presence || ''
      subject_name = @feedback_request.subject_of_feedback_teammate&.person&.casual_name.presence || 'the subject'
      rating_phrase = rating.to_s.humanize.downcase
      object_name = question.rateable&.name.presence || question.rateable&.title.presence || 'this'

      sentence = "My experience is that #{subject_name} has shown a #{rating_phrase} example of #{object_name}."
      question_text.present? ? "#{question_text} #{sentence}" : sentence
    end
  end
end
