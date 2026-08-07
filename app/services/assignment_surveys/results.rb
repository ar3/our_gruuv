module AssignmentSurveys
  class Results
    DIMENSIONS = {
      understandable: :understandable_rating,
      possible: :possible_rating,
      relevant: :relevant_rating
    }.freeze

    ASSIGNMENT_SORTS = %w[name average responses].freeze
    DEFAULT_ASSIGNMENT_SORT = "name"

    attr_reader :organization, :teammates, :assignment_sort

    def initialize(organization:, teammates:, assignment_sort: DEFAULT_ASSIGNMENT_SORT)
      @organization = organization
      @teammates = teammates.includes(:person).order("people.last_name ASC", "people.first_name ASC").references(:person).to_a
      @assignment_sort = self.class.normalize_assignment_sort(assignment_sort)
    end

    def self.normalize_assignment_sort(value)
      sort = value.to_s.presence
      ASSIGNMENT_SORTS.include?(sort) ? sort : DEFAULT_ASSIGNMENT_SORT
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
      rows = latest_responses.group_by(&:assignment_id).values.map do |responses|
        latest_response = responses.max_by(&:created_at)
        distributions = distributions_for(responses)
        {
          assignment_id: latest_response.assignment_id,
          title: latest_response.snapshot_title,
          response_count: responses.size,
          distributions: distributions,
          overall_average: overall_average_for(distributions)
        }
      end
      sort_assignment_rows(rows)
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
        rated = responses.select { |response| response.public_send(attribute).present? }
        values = rated.map { |response| response.public_send(attribute) }
        counts = (1..6).to_h { |rating| [ rating, values.count(rating) ] }
        rating_sets = (1..6).to_h do |rating|
          set = rated.select { |response| response.public_send(attribute) == rating }
          [
            rating,
            {
              teammate_count: set.map { |response| response.submission.teammate_id }.uniq.size,
              assignment_count: set.map(&:assignment_id).uniq.size
            }
          ]
        end
        average = values.any? ? (values.sum.to_f / values.size).round(2) : nil
        [ dimension, { counts: counts, average: average, total: values.size, rating_sets: rating_sets } ]
      end
    end

    def overall_average_for(distributions)
      averages = DIMENSIONS.keys.filter_map { |dimension| distributions.dig(dimension, :average) }
      return nil if averages.empty?

      (averages.sum / averages.size.to_f).round(2)
    end

    def sort_assignment_rows(rows)
      case assignment_sort
      when "average"
        # Lowest overall average first so problems scan to the top; missing averages last.
        rows.sort_by { |row| [ row[:overall_average].nil? ? 1 : 0, row[:overall_average] || 0, row[:title].downcase ] }
      when "responses"
        # Most responses first; title as stable secondary key.
        rows.sort_by { |row| [ -row[:response_count], row[:title].downcase ] }
      else
        rows.sort_by { |row| row[:title].downcase }
      end
    end
  end
end
