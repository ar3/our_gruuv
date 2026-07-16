module AssignmentSurveys
  class Results
    DIMENSIONS = {
      understandable: :understandable_rating,
      possible: :possible_rating,
      relevant: :relevant_rating
    }.freeze

    attr_reader :organization, :teammates

    def initialize(organization:, teammates:)
      @organization = organization
      @teammates = teammates.includes(:person).order("people.last_name ASC", "people.first_name ASC").references(:person).to_a
    end

    def participation_rows
      teammates.map do |teammate|
        history = submissions_by_teammate.fetch(teammate.id, [])
        draft = history.find(&:draft?)
        latest_finalized = history.find(&:finalized?)

        {
          teammate: teammate,
          status: draft ? :draft : (latest_finalized ? :finalized : :not_started),
          draft: draft,
          latest_finalized: latest_finalized,
          submission_count: history.count(&:finalized?)
        }
      end
    end

    def latest_finalized_submissions
      @latest_finalized_submissions ||= teammates.filter_map do |teammate|
        submissions_by_teammate.fetch(teammate.id, []).find(&:finalized?)
      end
    end

    def overall_distributions
      distributions_for(latest_responses)
    end

    def assignment_rows
      latest_responses.group_by(&:assignment_id).values.map do |responses|
        latest_response = responses.max_by(&:created_at)
        {
          assignment_id: latest_response.assignment_id,
          title: latest_response.snapshot_title,
          response_count: responses.size,
          distributions: distributions_for(responses)
        }
      end.sort_by { |row| row[:title].downcase }
    end

    def finalized_teammate_count
      latest_finalized_submissions.size
    end

    def draft_teammate_count
      participation_rows.count { |row| row[:status] == :draft }
    end

    def not_started_teammate_count
      participation_rows.count { |row| row[:status] == :not_started }
    end

    private

    def submissions_by_teammate
      @submissions_by_teammate ||= begin
        scope = AssignmentSurveySubmission
          .where(organization: organization, teammate_id: teammates.map(&:id))
          .includes(:responses)
          .latest_first
        scope.group_by(&:teammate_id)
      end
    end

    def latest_responses
      @latest_responses ||= latest_finalized_submissions.flat_map(&:responses)
    end

    def distributions_for(responses)
      DIMENSIONS.to_h do |dimension, attribute|
        values = responses.filter_map { |response| response.public_send(attribute) }
        counts = (1..6).to_h { |rating| [ rating, values.count(rating) ] }
        average = values.any? ? (values.sum.to_f / values.size).round(2) : nil
        [ dimension, { counts: counts, average: average, total: values.size } ]
      end
    end
  end
end
