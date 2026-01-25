module FeedbackRequests
  class CreateService
    def self.call(feedback_request:, questions_attributes:, responder_teammate_ids:, current_teammate:)
      new(
        feedback_request: feedback_request,
        questions_attributes: questions_attributes,
        responder_teammate_ids: responder_teammate_ids,
        current_teammate: current_teammate
      ).call
    end

    def initialize(feedback_request:, questions_attributes:, responder_teammate_ids:, current_teammate:)
      @feedback_request = feedback_request
      @questions_attributes = questions_attributes || []
      @responder_teammate_ids = responder_teammate_ids || []
      @current_teammate = current_teammate
    end

    def call
      ApplicationRecord.transaction do
        # Set requestor
        @feedback_request.requestor_teammate = @current_teammate
        
        # Validate and save request
        unless @feedback_request.valid? && @feedback_request.save
          return Result.err(@feedback_request.errors.full_messages)
        end

        # Create questions
        # Handle both hash (Rails nested attributes) and array formats
        questions_array = if @questions_attributes.is_a?(Hash) || @questions_attributes.is_a?(ActionController::Parameters)
          @questions_attributes.to_h.values.map { |q| q.respond_to?(:to_h) ? q.to_h : q }
        elsif @questions_attributes.is_a?(Array)
          @questions_attributes
        else
          []
        end
        
        questions_array.each_with_index do |question_attrs, index|
          # Convert to hash if it's ActionController::Parameters
          attrs_hash = question_attrs.respond_to?(:to_h) ? question_attrs.to_h : question_attrs
          
          question = @feedback_request.feedback_request_questions.build(
            question_text: attrs_hash[:question_text] || attrs_hash['question_text'],
            position: attrs_hash[:position] || attrs_hash['position'] || index + 1,
            rateable_type: attrs_hash[:rateable_type].presence || attrs_hash['rateable_type'].presence,
            rateable_id: attrs_hash[:rateable_id].presence || attrs_hash['rateable_id'].presence
          )
          
          unless question.save
            return Result.err(question.errors.full_messages)
          end
        end

        # Create responder associations
        @responder_teammate_ids.each do |teammate_id|
          responder = @feedback_request.feedback_request_responders.build(teammate_id: teammate_id)
          unless responder.save
            return Result.err(responder.errors.full_messages)
          end
        end

        # State is now computed, so no need to validate/update it
        Result.ok(@feedback_request)
      end
    rescue => e
      Rails.logger.error "Failed to create feedback request: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      Result.err("Failed to create feedback request: #{e.message}")
    end
  end
end
