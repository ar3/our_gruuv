# frozen_string_literal: true

module AssignmentSurveys
  # Org-wide experience-survey adoption metrics for Assignments Insights.
  # Snapshot metrics are all-time; submit trends respect +chart_range+.
  class InsightsAnalytics
    PUBLIC_THRESHOLD = AssignmentAnalytics::PUBLIC_THRESHOLD

    FIELD_KEYS = [
      [ :understandable_rating, "Understandable" ],
      [ :possible_rating, "Possible" ],
      [ :relevant_rating, "Relevant" ],
      [ :personal_alignment, "Personal alignment" ]
    ].freeze

    ALIGNMENT_ORDER = %w[only_if_necessary neutral like love].freeze
    ALIGNMENT_LABELS = {
      "only_if_necessary" => "Only If Necessary",
      "neutral" => "Neutral",
      "like" => "Like",
      "love" => "Love",
      "prefer_not" => "Prefer not"
    }.freeze

    Result = Struct.new(
      :active_teammate_count,
      :ever_submitted_teammate_count,
      :never_submitted_teammate_count,
      :field_take_rates_chart_data,
      :personal_alignment_mix_chart_data,
      :assignment_eligibility_chart_data,
      :assignment_coverage_chart_data,
      :public_aggregate_chart_data,
      :comment_stats,
      :submits_by_week_chart_data,
      keyword_init: true
    )

    CommentStats = Struct.new(
      :submitted_response_count,
      :with_comment_count,
      :comment_rate,
      keyword_init: true
    )

    def initialize(organization:, chart_range:)
      @organization = organization
      @chart_range = chart_range
    end

    def call
      Result.new(
        active_teammate_count: active_teammate_ids.size,
        ever_submitted_teammate_count: ever_submitted_teammate_ids.size,
        never_submitted_teammate_count: (active_teammate_ids - ever_submitted_teammate_ids).size,
        field_take_rates_chart_data: field_take_rates_chart_data,
        personal_alignment_mix_chart_data: personal_alignment_mix_chart_data,
        assignment_eligibility_chart_data: assignment_eligibility_chart_data,
        assignment_coverage_chart_data: assignment_coverage_chart_data,
        public_aggregate_chart_data: public_aggregate_chart_data,
        comment_stats: comment_stats,
        submits_by_week_chart_data: submits_by_week_chart_data
      )
    end

    private

    attr_reader :organization, :chart_range

    def active_teammate_ids
      @active_teammate_ids ||= CompanyTeammate
        .where(organization: organization)
        .employed
        .pluck(:id)
        .to_set
    end

    def content_submitted_scope
      AssignmentSurveyResponse
        .submitted
        .where(organization_id: organization.id)
        .where(
          "understandable_rating IS NOT NULL OR possible_rating IS NOT NULL OR " \
          "relevant_rating IS NOT NULL OR personal_alignment IS NOT NULL"
        )
    end

    def ever_submitted_teammate_ids
      @ever_submitted_teammate_ids ||= content_submitted_scope
        .where(teammate_id: active_teammate_ids.to_a)
        .distinct
        .pluck(:teammate_id)
        .to_set
    end

    def field_take_rates_chart_data
      categories = FIELD_KEYS.map(&:last)
      data = FIELD_KEYS.map do |column, _label|
        teammate_ids_with_field(column).intersection(active_teammate_ids).size
      end

      {
        categories: categories,
        series: [ { name: "Active teammates (ever)", data: data } ]
      }
    end

    def teammate_ids_with_field(column)
      content_submitted_scope
        .where.not(column => nil)
        .distinct
        .pluck(:teammate_id)
        .to_set
    end

    def personal_alignment_mix_chart_data
      counts = content_submitted_scope
        .where.not(personal_alignment: nil)
        .group(:personal_alignment)
        .count

      categories = ALIGNMENT_ORDER.map { |key| ALIGNMENT_LABELS[key] }
      data = ALIGNMENT_ORDER.map { |key| counts[key] || 0 }

      extra_keys = counts.keys - ALIGNMENT_ORDER
      extra_keys.sort.each do |key|
        categories << ALIGNMENT_LABELS.fetch(key, key.to_s.humanize)
        data << counts[key]
      end

      {
        categories: categories,
        series: [ { name: "Submitted responses", data: data } ]
      }
    end

    def unarchived_assignment_ids
      @unarchived_assignment_ids ||= Assignment.unarchived.for_company(organization).pluck(:id).to_set
    end

    def survey_eligible_assignment_ids
      @survey_eligible_assignment_ids ||= begin
        active_held = AssignmentTenure.active
          .joins(:assignment)
          .where(assignments: { company_id: organization.id })
          .merge(Assignment.unarchived)
          .distinct
          .pluck(:assignment_id)

        held_position_ids = EmploymentTenure.active
          .where(company_id: organization.id)
          .select(:position_id)
        required_on_held_positions = PositionAssignment.required
          .joins(:assignment)
          .where(position_id: held_position_ids)
          .merge(Assignment.unarchived)
          .distinct
          .pluck(:assignment_id)

        (active_held + required_on_held_positions).to_set
      end
    end

    def assignment_eligibility_chart_data
      eligible = survey_eligible_assignment_ids.size
      neither = (unarchived_assignment_ids - survey_eligible_assignment_ids).size

      {
        categories: [ "Active and/or required", "Neither active nor required" ],
        series: [ { name: "Assignments", data: [ eligible, neither ] } ]
      }
    end

    def respondent_counts_by_assignment
      @respondent_counts_by_assignment ||= content_submitted_scope
        .group(:assignment_id)
        .distinct
        .count(:teammate_id)
    end

    def assignment_coverage_chart_data
      eligible_ids = survey_eligible_assignment_ids
      with_response = eligible_ids.count { |id| (respondent_counts_by_assignment[id] || 0) >= 1 }
      without_response = eligible_ids.size - with_response

      {
        categories: [ "≥1 submitted response", "No submitted responses" ],
        series: [ { name: "Survey-eligible assignments", data: [ with_response, without_response ] } ]
      }
    end

    def public_aggregate_chart_data
      eligible_ids = survey_eligible_assignment_ids
      met = eligible_ids.count { |id| (respondent_counts_by_assignment[id] || 0) > PUBLIC_THRESHOLD }
      not_met = eligible_ids.size - met

      {
        categories: [ "Public aggregate ready (>#{PUBLIC_THRESHOLD})", "Below threshold" ],
        series: [ { name: "Survey-eligible assignments", data: [ met, not_met ] } ]
      }
    end

    def comment_stats
      submitted = content_submitted_scope
      total = submitted.count
      with_comment = submitted.where.not(comment: [ nil, "" ]).count
      rate = total.zero? ? 0.0 : (with_comment.to_f / total * 100).round(1)

      CommentStats.new(
        submitted_response_count: total,
        with_comment_count: with_comment,
        comment_rate: rate
      )
    end

    def submits_by_week_chart_data
      return { categories: [], series: [] } if chart_range.nil?

      classified = classify_submits
      in_range = classified.select { |row| chart_range.cover?(row[:submitted_at]) }

      end_date = chart_range.end.to_date
      start_date = chart_range.begin.to_date
      week_dates = (start_date..end_date).to_a.map(&:beginning_of_week).uniq.sort
      categories = week_dates.map { |week| week.strftime("%b %d, %Y") }

      first_by_week = Hash.new(0)
      resubmit_by_week = Hash.new(0)
      in_range.each do |row|
        week = row[:submitted_at].to_date.beginning_of_week
        if row[:first]
          first_by_week[week] += 1
        else
          resubmit_by_week[week] += 1
        end
      end

      {
        categories: categories,
        series: [
          { name: "First submits", data: week_dates.map { |week| first_by_week[week] || 0 } },
          { name: "Re-submits", data: week_dates.map { |week| resubmit_by_week[week] || 0 } }
        ]
      }
    end

    def classify_submits
      rows = content_submitted_scope
        .order(:submitted_at, :id)
        .pluck(:teammate_id, :assignment_id, :submitted_at)

      seen = Set.new
      rows.map do |teammate_id, assignment_id, submitted_at|
        key = [ teammate_id, assignment_id ]
        first = !seen.include?(key)
        seen.add(key)
        { submitted_at: submitted_at, first: first }
      end
    end
  end
end
