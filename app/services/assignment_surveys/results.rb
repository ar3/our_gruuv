module AssignmentSurveys
  class Results
    DIMENSIONS = {
      understandable: :understandable_rating,
      possible: :possible_rating,
      relevant: :relevant_rating
    }.freeze

    ASSIGNMENT_SORTS = %w[name average responses].freeze
    DEFAULT_ASSIGNMENT_SORT = "name"

    attr_reader :organization, :teammates, :assignment_sort, :maintained_assignment_ids

    def initialize(organization:, teammates:, maintained_assignment_ids: [], assignment_sort: DEFAULT_ASSIGNMENT_SORT)
      @organization = organization
      @teammates = teammates.includes(:person).order("people.last_name ASC", "people.first_name ASC").references(:person).to_a
      @maintained_assignment_ids = Array(maintained_assignment_ids).map(&:to_i).uniq
      @assignment_sort = self.class.normalize_assignment_sort(assignment_sort)
    end

    def self.normalize_assignment_sort(value)
      sort = value.to_s.presence
      ASSIGNMENT_SORTS.include?(sort) ? sort : DEFAULT_ASSIGNMENT_SORT
    end

    def participation_rows
      teammates.map do |teammate|
        teammate_responses = responses_by_teammate.fetch(teammate.id, [])
        submitted = teammate_responses.select(&:submitted?)
        in_progress = teammate_responses.select(&:in_progress?)
        in_progress_with_content = in_progress.select(&:content?)
        latest_submitted = submitted.max_by { |response| [ response.submitted_at || Time.at(0), response.id ] }

        status =
          if in_progress_with_content.any?
            :in_progress
          elsif submitted.any?
            :submitted
          else
            :not_started
          end

        {
          teammate: teammate,
          status: status,
          in_progress_count: in_progress_with_content.size,
          latest_submitted: latest_submitted,
          response_count: submitted.size
        }
      end
    end

    def overall_distributions
      distributions_for(latest_responses)
    end

    def assignment_rows
      hierarchy_rows = rows_from_responses(latest_responses).index_by { |row| row[:assignment_id] }
      org_wide_rows = rows_from_responses(org_wide_responses_for_maintained).index_by { |row| row[:assignment_id] }

      assignment_ids = hierarchy_rows.keys | org_wide_rows.keys | maintained_assignment_ids
      rows = assignment_ids.filter_map do |assignment_id|
        if maintained_assignment_ids.include?(assignment_id)
          row = org_wide_rows[assignment_id]
          next unless row

          row.merge(org_wide: true)
        else
          row = hierarchy_rows[assignment_id]
          next unless row

          row.merge(org_wide: false)
        end
      end
      sort_assignment_rows(rows)
    end

    def show_people_results?
      teammates.any?
    end

    def show_overall_results?
      finalized_teammate_count.positive?
    end

    def show_assignment_score_results?
      assignment_rows.any?
    end

    def finalized_teammate_count
      latest_responses.map(&:teammate_id).uniq.size
    end

    def in_progress_teammate_count
      participation_rows.count { |row| row[:status] == :in_progress }
    end

    def not_started_teammate_count
      participation_rows.count { |row| row[:status] == :not_started }
    end

    private

    def responses_by_teammate
      @responses_by_teammate ||= AssignmentSurveyResponse
        .where(organization: organization, teammate_id: teammates.map(&:id))
        .includes(:assignment)
        .to_a
        .group_by(&:teammate_id)
    end

    def latest_responses
      @latest_responses ||= latest_responses_from(responses_by_teammate.values.flatten.select(&:submitted?))
    end

    def org_wide_responses_for_maintained
      return [] if maintained_assignment_ids.empty?

      @org_wide_responses_for_maintained ||= begin
        responses = AssignmentSurveyResponse
          .submitted
          .where(organization: organization)
          .includes(:assignment)
          .latest_submitted_first
          .to_a

        latest_responses_from(responses).select do |response|
          maintained_assignment_ids.include?(response.assignment_id)
        end
      end
    end

    def latest_responses_from(responses)
      keyed = {}
      responses.sort_by { |response| [ response.submitted_at || Time.at(0), response.id ] }.reverse_each do |response|
        next unless response.content?

        key = [ response.teammate_id, response.assignment_id ]
        keyed[key] ||= response
      end
      keyed.values
    end

    def rows_from_responses(responses)
      responses.group_by(&:assignment_id).values.map do |grouped|
        latest_response = grouped.max_by(&:submitted_at)
        distributions = distributions_for(grouped)
        {
          assignment_id: latest_response.assignment_id,
          title: latest_response.snapshot_title,
          response_count: grouped.size,
          distributions: distributions,
          overall_average: overall_average_for(distributions)
        }
      end
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
              teammate_count: set.map(&:teammate_id).uniq.size,
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
        rows.sort_by { |row| [ row[:overall_average].nil? ? 1 : 0, row[:overall_average] || 0, row[:title].downcase ] }
      when "responses"
        rows.sort_by { |row| [ -row[:response_count], row[:title].downcase ] }
      else
        rows.sort_by { |row| row[:title].downcase }
      end
    end
  end
end
