# frozen_string_literal: true

module PositionsHealth
  # Org-wide Title EAS rollup for Position · Health — department bars of titles.
  class TitleExpectationAlignmentOverview
    STALE_AFTER = 1.day

    BAND_ORDER = (
      Titles::ExpectationAlignmentScore::SCORE_BANDS.map { |band| band[:key] } + [:unscored]
    ).freeze

    BAND_COLORS = AssignmentsHealth::ExpectationAlignmentOverview::BAND_COLORS

    TitleRow = Struct.new(
      :title,
      :score,
      :band_key,
      :missing?,
      :stale?,
      :refreshable?,
      keyword_init: true
    )

    DepartmentGroup = Struct.new(
      :department,
      :label,
      :titles,
      keyword_init: true
    )

    Result = Struct.new(
      :total_count,
      :scored_count,
      :missing_count,
      :stale_count,
      :refreshable_count,
      :band_counts,
      :department_groups,
      :all_title_ids,
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
      titles = organization.titles
                           .unarchived
                           .includes(:department, :position_major_level, :expectation_alignment_score_cache)
                           .to_a

      rows = titles.map { |title| build_row(title) }
      scored = rows.reject(&:missing?)
      missing = rows.select(&:missing?)
      stale = rows.select(&:stale?)
      refreshable = rows.select(&:refreshable?)

      Result.new(
        total_count: rows.size,
        scored_count: scored.size,
        missing_count: missing.size,
        stale_count: stale.size,
        refreshable_count: refreshable.size,
        band_counts: band_counts_for(rows),
        department_groups: department_groups_for(rows),
        all_title_ids: rows.map { |row| row.title.id }
      )
    end

    private

    attr_reader :organization, :reference_time

    def band_counts_for(rows)
      counts = BAND_ORDER.index_with { 0 }
      rows.each { |row| counts[row.band_key] = counts[row.band_key].to_i + 1 }
      counts
    end

    def build_row(title)
      cache = title.expectation_alignment_score_cache
      missing = cache.blank?
      stale = cache.present? && cache.calculated_at < (reference_time - STALE_AFTER)
      score = missing ? nil : cache.score&.to_f
      band_key =
        if missing
          :unscored
        else
          Titles::ExpectationAlignmentScore.band_for_score(score)&.fetch(:key) || :unscored
        end

      TitleRow.new(
        title: title,
        score: score,
        band_key: band_key,
        missing?: missing,
        stale?: stale,
        refreshable?: missing || stale
      )
    end

    def department_groups_for(rows)
      grouped = rows.group_by { |row| row.title.department }
      ordered_keys = grouped.keys.sort_by { |dept| dept ? dept.display_name.to_s.downcase : "" }
      # Company-wide (nil) first, matching positions index convention.
      ordered_keys = [nil] + ordered_keys.compact if grouped.key?(nil)

      ordered_keys.uniq.filter_map do |department|
        dept_rows = grouped[department]
        next if dept_rows.blank?

        DepartmentGroup.new(
          department: department,
          label: department&.display_name || "Company-wide",
          titles: sort_titles(dept_rows)
        )
      end
    end

    # Best → worst; unscored last (treated as worst).
    def sort_titles(rows)
      rows.sort_by do |row|
        if row.missing?
          [1, 0.0, row.title.external_title.to_s.downcase]
        else
          [0, -row.score.to_f, row.title.external_title.to_s.downcase]
        end
      end
    end
  end
end
