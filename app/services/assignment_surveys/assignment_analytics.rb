# frozen_string_literal: true

module AssignmentSurveys
  class AssignmentAnalytics
    PUBLIC_THRESHOLD = 5

    DetailRow = Struct.new(
      :teammate,
      :response,
      :submitted_at,
      :understandable_rating,
      :possible_rating,
      :relevant_rating,
      :personal_alignment,
      :comment,
      keyword_init: true
    )

    HistoryPoint = Struct.new(
      :submitted_at,
      :understandable_rating,
      :possible_rating,
      :relevant_rating,
      :personal_alignment,
      :teammate_id,
      keyword_init: true
    )

    Result = Struct.new(
      :respondent_count,
      :public_threshold_met?,
      :public_distributions,
      :personal_alignment_counts,
      :people_manager_rows,
      :people_manager_eligible?,
      :org_wide_rows,
      :org_wide_eligible?,
      :history_points,
      :maap_or_maintainer_names,
      keyword_init: true
    )

    def initialize(assignment:, viewer:, organization:)
      @assignment = assignment
      @viewer = viewer
      @organization = organization
    end

    def call
      latest = latest_responses_by_teammate
      all_history = all_responses_chronological

      Result.new(
        respondent_count: latest.size,
        public_threshold_met?: latest.size > PUBLIC_THRESHOLD,
        public_distributions: distributions_for(latest.values),
        personal_alignment_counts: alignment_counts_for(latest.values),
        people_manager_rows: detail_rows_for(people_manager_teammate_ids, latest),
        people_manager_eligible?: people_manager_eligible?,
        org_wide_rows: detail_rows_for(latest.keys, latest),
        org_wide_eligible?: org_wide_eligible?,
        history_points: all_history.map { |response| history_point(response) },
        maap_or_maintainer_names: maap_or_maintainer_casual_names
      )
    end

    private

    attr_reader :assignment, :viewer, :organization

    def submitted_responses_scope
      AssignmentSurveyResponse
        .submitted
        .where(assignment_id: assignment.id, organization_id: organization.id)
        .includes(company_teammate: :person)
    end

    def all_responses_chronological
      @all_responses_chronological ||= submitted_responses_scope
        .order(submitted_at: :asc, id: :asc)
        .to_a
    end

    def latest_responses_by_teammate
      @latest_responses_by_teammate ||= begin
        all_responses_chronological.reverse_each.each_with_object({}) do |response, memo|
          memo[response.teammate_id] ||= response
        end
      end
    end

    def people_manager_eligible?
      return false if viewer.blank?

      people_manager_teammate_ids.any?
    end

    def org_wide_eligible?
      return false if viewer.blank?

      viewer.can_manage_maap? || assignment.maintained_by?(viewer)
    end

    def people_manager_teammate_ids
      @people_manager_teammate_ids ||= begin
        return [] if viewer.blank?

        hierarchy_ids = CompanyTeammate
          .self_and_reporting_hierarchy(viewer, organization)
          .employed
          .where.not(id: viewer.id)
          .pluck(:id)
        hierarchy_ids & latest_responses_by_teammate.keys
      end
    end

    def detail_rows_for(teammate_ids, latest)
      Array(teammate_ids).filter_map do |teammate_id|
        response = latest[teammate_id]
        next unless response

        DetailRow.new(
          teammate: response.company_teammate,
          response: response,
          submitted_at: response.submitted_at,
          understandable_rating: response.understandable_rating,
          possible_rating: response.possible_rating,
          relevant_rating: response.relevant_rating,
          personal_alignment: response.personal_alignment,
          comment: response.comment
        )
      end.sort_by { |row| [ row.teammate.person.last_name.to_s, row.teammate.person.first_name.to_s ] }
    end

    def history_point(response)
      HistoryPoint.new(
        submitted_at: response.submitted_at,
        understandable_rating: response.understandable_rating,
        possible_rating: response.possible_rating,
        relevant_rating: response.relevant_rating,
        personal_alignment: response.personal_alignment,
        teammate_id: response.teammate_id
      )
    end

    def distributions_for(responses)
      AssignmentSurveys::Results::DIMENSIONS.to_h do |dimension, attribute|
        rated = responses.select { |response| response.public_send(attribute).present? }
        values = rated.map { |response| response.public_send(attribute) }
        counts = (1..6).to_h { |rating| [ rating, values.count(rating) ] }
        average = values.any? ? (values.sum.to_f / values.size).round(2) : nil
        [ dimension, { counts: counts, average: average, total: values.size } ]
      end
    end

    def alignment_counts_for(responses)
      AssignmentSurveyResponse::PERSONAL_ALIGNMENT_OPTIONS.to_h do |_label, value|
        [ value, responses.count { |response| response.personal_alignment == value } ]
      end
    end

    def maap_or_maintainer_casual_names
      maap_ids = organization.company_teammates.employed.with_maap_management.pluck(:id)
      maintainer_ids = assignment.object_maintainers.pluck(:company_teammate_id)
      CompanyTeammate
        .where(id: (maap_ids | maintainer_ids))
        .includes(:person)
        .map { |teammate| teammate.person.casual_name }
        .uniq
        .sort
    end
  end
end
