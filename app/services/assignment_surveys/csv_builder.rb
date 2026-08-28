require "csv"

module AssignmentSurveys
  class CsvBuilder
    HEADERS = [
      "Teammate",
      "Email",
      "Response ID",
      "Status",
      "Submitted at",
      "Latest for assignment",
      "Assignment",
      "Assignment source",
      "Understandable (1-6)",
      "Possible (1-6)",
      "Relevant (1-6)",
      "Personal alignment",
      "Comment"
    ].freeze

    def initialize(organization:, teammates:)
      @organization = organization
      @teammates = teammates.includes(:person).to_a
    end

    def call
      CSV.generate(headers: true) do |csv|
        csv << HEADERS
        teammates.sort_by { |teammate| teammate.person.display_name.downcase }.each do |teammate|
          teammate_responses = responses_by_teammate.fetch(teammate.id, [])
          if teammate_responses.empty?
            csv << empty_row_for(teammate)
          else
            teammate_responses.each do |response|
              csv << response_row(teammate, response)
            end
          end
        end
      end
    end

    private

    attr_reader :organization, :teammates

    def responses_by_teammate
      @responses_by_teammate ||= AssignmentSurveyResponse
        .where(organization: organization, teammate_id: teammates.map(&:id))
        .includes(:assignment)
        .order(submitted_at: :desc, id: :desc)
        .group_by(&:teammate_id)
    end

    def latest_submitted_ids
      @latest_submitted_ids ||= begin
        ids = Set.new
        responses_by_teammate.each_value do |responses|
          responses.select(&:submitted?).group_by(&:assignment_id).each_value do |group|
            latest = group.max_by { |response| [ response.submitted_at || Time.at(0), response.id ] }
            ids << latest.id
          end
        end
        ids
      end
    end

    def empty_row_for(teammate)
      [
        teammate.person.display_name,
        teammate.person.email,
        nil,
        "not_started"
      ]
    end

    def response_row(teammate, response)
      [
        teammate.person.display_name,
        teammate.person.email,
        response.id,
        response.submitted? ? "submitted" : "in_progress",
        response.submitted_at&.iso8601,
        response.submitted? && latest_submitted_ids.include?(response.id),
        response.snapshot_title,
        response.source_label,
        response.understandable_rating,
        response.possible_rating,
        response.relevant_rating,
        response.personal_alignment,
        response.comment
      ]
    end
  end
end
