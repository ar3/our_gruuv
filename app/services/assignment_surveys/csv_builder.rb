require "csv"

module AssignmentSurveys
  class CsvBuilder
    HEADERS = [
      "Teammate",
      "Email",
      "Submission ID",
      "Submission status",
      "Started at",
      "Finalized at",
      "Latest finalized submission",
      "Assignment",
      "Assignment source",
      "Understandable (1-6)",
      "Possible (1-6)",
      "Relevant (1-6)",
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
          teammate_submissions = submissions_by_teammate.fetch(teammate.id, [])
          if teammate_submissions.empty?
            csv << empty_row_for(teammate)
          else
            teammate_submissions.each do |submission|
              submission.responses.each do |response|
                csv << response_row(teammate, submission, response)
              end
            end
          end
        end
      end
    end

    private

    attr_reader :organization, :teammates

    def submissions_by_teammate
      @submissions_by_teammate ||= AssignmentSurveySubmission
        .where(organization: organization, teammate_id: teammates.map(&:id))
        .includes(:responses)
        .latest_first
        .group_by(&:teammate_id)
    end

    def latest_finalized_ids
      @latest_finalized_ids ||= submissions_by_teammate.values.filter_map do |submissions|
        submissions.find(&:finalized?)&.id
      end.to_set
    end

    def empty_row_for(teammate)
      [
        teammate.person.display_name,
        teammate.person.email,
        nil,
        "not_started"
      ]
    end

    def response_row(teammate, submission, response)
      [
        teammate.person.display_name,
        teammate.person.email,
        submission.id,
        submission.status,
        submission.created_at.iso8601,
        submission.finalized_at&.iso8601,
        latest_finalized_ids.include?(submission.id),
        response.snapshot_title,
        response.source_label,
        response.understandable_rating,
        response.possible_rating,
        response.relevant_rating,
        response.comment
      ]
    end
  end
end
