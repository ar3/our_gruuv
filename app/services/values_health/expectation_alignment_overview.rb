# frozen_string_literal: true

module ValuesHealth
  # Org-wide Expectation Alignment Score rollup for Values · Health.
  class ExpectationAlignmentOverview
    STALE_AFTER = 1.day
    LIST_LIMIT = 10

    BAND_COLORS = AssignmentsHealth::ExpectationAlignmentOverview::BAND_COLORS

    Row = Struct.new(
      :aspiration,
      :score,
      :band,
      :calculated_at,
      :missing?,
      :stale?,
      :refreshable?,
      keyword_init: true
    )

    Result = Struct.new(
      :total_count,
      :scored_count,
      :missing_count,
      :stale_count,
      :refreshable_count,
      :average_score,
      :distribution,
      :chart_data,
      :best,
      :worst,
      :refreshable_rows,
      :refreshable_aspiration_ids,
      keyword_init: true
    )

    def initialize(organization:, reference_time: Time.current)
      @organization = organization
      @reference_time = reference_time
    end

    def call
      rows = build_rows
      scored = rows.reject(&:missing?).select { |row| row.score.present? }
      refreshable_rows = rows.select(&:refreshable?)
      refreshable_ids = refreshable_rows.map { |row| row.aspiration.id }

      Result.new(
        total_count: rows.size,
        scored_count: scored.size,
        missing_count: rows.count(&:missing?),
        stale_count: rows.count { |row| !row.missing? && row.stale? },
        refreshable_count: refreshable_ids.size,
        average_score: average_for(scored),
        distribution: distribution_for(rows),
        chart_data: chart_data_for(rows),
        best: scored.sort_by { |row| [-row.score.to_f, row.aspiration.name.to_s.downcase] }.first(LIST_LIMIT),
        worst: scored.sort_by { |row| [row.score.to_f, row.aspiration.name.to_s.downcase] }.first(LIST_LIMIT),
        refreshable_rows: refreshable_rows,
        refreshable_aspiration_ids: refreshable_ids
      )
    end

    private

    attr_reader :organization, :reference_time

    def aspirations
      @aspirations ||= Aspiration.for_company(organization).ordered.to_a
    end

    def scores_by_aspiration_id
      @scores_by_aspiration_id ||= AspirationExpectationAlignmentScore
        .where(organization_id: organization.id, aspiration_id: aspirations.map(&:id))
        .index_by(&:aspiration_id)
    end

    def build_rows
      aspirations.map do |aspiration|
        record = scores_by_aspiration_id[aspiration.id]
        missing = record.nil?
        calculated_at = record&.calculated_at
        stale = missing || calculated_at.blank? || calculated_at < (reference_time - STALE_AFTER)
        score = missing ? nil : record.score&.to_f
        band = Aspirations::ExpectationAlignmentScore.band_for_score(score)

        Row.new(
          aspiration: aspiration,
          score: score,
          band: band,
          calculated_at: calculated_at,
          missing?: missing,
          stale?: stale,
          refreshable?: stale
        )
      end
    end

    def average_for(scored_rows)
      return nil if scored_rows.empty?

      (scored_rows.sum { |row| row.score.to_f } / scored_rows.size).round(1)
    end

    def distribution_for(rows)
      counts = Hash.new(0)
      rows.each do |row|
        key = row.band&.fetch(:key) || :unscored
        counts[key] += 1
      end

      bands = Aspirations::ExpectationAlignmentScore::SCORE_BANDS.map do |band|
        {
          key: band[:key],
          label: band[:label],
          count: counts[band[:key]],
          color: BAND_COLORS.fetch(band[:key])
        }
      end

      bands + [
        {
          key: :unscored,
          label: "No score",
          count: counts[:unscored],
          color: BAND_COLORS.fetch(:unscored)
        }
      ]
    end

    def chart_data_for(rows)
      dist = distribution_for(rows)
      {
        categories: dist.map { |bucket| bucket[:label] },
        series: [
          {
            name: "Values",
            data: dist.map { |bucket| { y: bucket[:count], color: bucket[:color] } }
          }
        ]
      }
    end
  end
end
