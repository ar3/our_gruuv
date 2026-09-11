# frozen_string_literal: true

module DepartmentsHealth
  # Per-department rollup of Title, Position, and Assignment Expectation Alignment Scores.
  class ExpectationAlignmentOverview
    STALE_AFTER = 1.day
    BAND_COLORS = AssignmentsHealth::ExpectationAlignmentOverview::BAND_COLORS

    ScoreSummary = Struct.new(
      :count,
      :scored_count,
      :missing_count,
      :stale_count,
      :average_score,
      :band_key,
      keyword_init: true
    )

    DepartmentRow = Struct.new(
      :department,
      :label,
      :titles,
      :positions,
      :assignments,
      :combined_average,
      :combined_band_key,
      keyword_init: true
    )

    Result = Struct.new(
      :department_rows,
      :department_count,
      :combined_average,
      :combined_band_key,
      :title_ids,
      :position_ids,
      :assignment_ids,
      keyword_init: true
    )

    def self.call(organization:, reference_time: Time.current)
      new(organization: organization, reference_time: reference_time).call
    end

    def initialize(organization:, reference_time: Time.current)
      @organization = organization
      @reference_time = reference_time
    end

    def call
      rows = build_department_rows
      combined_scores = rows.filter_map(&:combined_average)
      combined_average = average_of(combined_scores)
      combined_band = band_key_for(combined_average)

      Result.new(
        department_rows: rows,
        department_count: rows.count { |row| row.department.present? },
        combined_average: combined_average,
        combined_band_key: combined_band,
        title_ids: titles.map(&:id),
        position_ids: positions.map(&:id),
        assignment_ids: assignments.map(&:id)
      )
    end

    private

    attr_reader :organization, :reference_time

    def titles
      @titles ||= organization.titles
                              .unarchived
                              .includes(:department, :expectation_alignment_score_cache)
                              .to_a
    end

    def positions
      @positions ||= Position.unarchived
                             .for_company(organization)
                             .includes(:expectation_alignment_score_cache, title: :department)
                             .to_a
    end

    def assignments
      @assignments ||= Assignment.unarchived
                                 .for_company(organization)
                                 .includes(:department)
                                 .to_a
    end

    def assignment_scores_by_id
      @assignment_scores_by_id ||= AssignmentExpectationAlignmentScore
        .where(organization_id: organization.id, assignment_id: assignments.map(&:id))
        .index_by(&:assignment_id)
    end

    def build_department_rows
      dept_keys = (titles.map(&:department) + positions.map { |p| p.title.department } + assignments.map(&:department)).uniq
      ordered = dept_keys.sort_by { |dept| dept ? dept.display_name.to_s.downcase : "" }
      ordered = [nil] + ordered.compact if dept_keys.include?(nil)

      ordered.uniq.map do |department|
        title_summary = summary_for_titles(titles.select { |t| t.department == department })
        position_summary = summary_for_positions(positions.select { |p| p.title.department == department })
        assignment_summary = summary_for_assignments(assignments.select { |a| a.department == department })
        combined = average_of([title_summary.average_score, position_summary.average_score, assignment_summary.average_score].compact)

        DepartmentRow.new(
          department: department,
          label: department&.display_name || "Company-wide",
          titles: title_summary,
          positions: position_summary,
          assignments: assignment_summary,
          combined_average: combined,
          combined_band_key: band_key_for(combined)
        )
      end
    end

    def summary_for_titles(dept_titles)
      scores = []
      missing = 0
      stale = 0
      dept_titles.each do |title|
        cache = title.expectation_alignment_score_cache
        if cache.blank?
          missing += 1
          next
        end
        stale += 1 if cache.calculated_at < (reference_time - STALE_AFTER)
        scores << cache.score.to_f if cache.score.present?
      end
      build_summary(count: dept_titles.size, scores: scores, missing: missing, stale: stale)
    end

    def summary_for_positions(dept_positions)
      scores = []
      missing = 0
      stale = 0
      dept_positions.each do |position|
        cache = position.expectation_alignment_score_cache
        if cache.blank?
          missing += 1
          next
        end
        stale += 1 if cache.calculated_at < (reference_time - STALE_AFTER)
        scores << cache.score.to_f if cache.score.present?
      end
      build_summary(count: dept_positions.size, scores: scores, missing: missing, stale: stale)
    end

    def summary_for_assignments(dept_assignments)
      scores = []
      missing = 0
      stale = 0
      dept_assignments.each do |assignment|
        record = assignment_scores_by_id[assignment.id]
        if record.nil?
          missing += 1
          next
        end
        stale += 1 if record.calculated_at.blank? || record.calculated_at < (reference_time - STALE_AFTER)
        scores << record.score.to_f if record.score.present?
      end
      build_summary(count: dept_assignments.size, scores: scores, missing: missing, stale: stale)
    end

    def build_summary(count:, scores:, missing:, stale:)
      average = average_of(scores)
      ScoreSummary.new(
        count: count,
        scored_count: scores.size,
        missing_count: missing,
        stale_count: stale,
        average_score: average,
        band_key: band_key_for(average)
      )
    end

    def average_of(scores)
      return nil if scores.blank?

      (scores.sum.to_f / scores.size).round(1)
    end

    def band_key_for(score)
      return :unscored if score.nil?

      AssignmentSurveys::ExpectationAlignmentScore.band_for_score(score)&.fetch(:key) || :unscored
    end
  end
end
