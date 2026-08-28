# frozen_string_literal: true

module AssignmentSurveys
  class Submitter
    class Error < StandardError; end

    def initialize(teammate:, organization:, response_ids: nil)
      @teammate = teammate
      @organization = organization
      @response_ids = Array(response_ids).presence
    end

    def call
      to_submit = selected_responses
      raise Error, "Add feedback on at least one assignment before submitting" if to_submit.empty?

      AssignmentSurveyResponse.transaction do
        to_submit.each(&:submit!)
      end

      to_submit
    end

    private

    attr_reader :teammate, :organization, :response_ids

    def selected_responses
      scope = teammate.assignment_survey_responses
        .in_progress
        .where(organization: organization)
        .to_a
        .select(&:content?)

      return scope if response_ids.blank?

      ids = response_ids.map(&:to_i)
      scope.select { |response| ids.include?(response.id) }
    end
  end
end
