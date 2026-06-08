# frozen_string_literal: true

module TeammateOgos
  class FeedbackRequestRow
    attr_reader :feedback_request

    def initialize(feedback_request:, viewing_teammate:, current_person:, company:)
      @feedback_request = feedback_request
      @viewing_teammate = viewing_teammate
      @current_person = current_person
      @company = company
      @visibility_query = ObservationVisibilityQuery.new(current_person, company)
    end

    def visible_observations
      @visible_observations ||= feedback_request.observations.select do |observation|
        observation.published? && visibility_query.visible_to?(observation)
      end
    end

    def visible_observations_count
      visible_observations.size
    end

    def responses_label
      count = visible_observations_count
      suffix = count == 1 ? "response" : "responses"
      if viewing_teammate == feedback_request.subject_of_feedback_teammate
        "#{count} #{suffix} visible to you"
      else
        "#{count} #{suffix} visible to you"
      end
    end

    def show_responder_details?
      return false unless viewing_teammate

      viewing_teammate == feedback_request.requestor_teammate
    end

    def visible_responders
      return [] unless show_responder_details?

      visible_observations.filter_map do |observation|
        CompanyTeammate.find_by(organization_id: company.id, person_id: observation.observer_id)
      end.uniq
    end

    def awaiting_responders
      return [] unless show_responder_details?

      visible_responder_ids = visible_responders.map(&:id)
      feedback_request.responders.reject { |responder| visible_responder_ids.include?(responder.id) }
    end

    private

    attr_reader :viewing_teammate, :current_person, :company, :visibility_query
  end
end
