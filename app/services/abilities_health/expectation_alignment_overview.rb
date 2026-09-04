# frozen_string_literal: true

module AbilitiesHealth
  # Org-wide Expectation Alignment Score rollup for Abilities · Health.
  # Stub: all abilities are unscored until ability alignment scoring ships.
  class ExpectationAlignmentOverview
    LIST_LIMIT = 10

    BAND_COLORS = {
      strongly_misaligned: "#a02734",
      misaligned: "#ca3b49",
      slightly_misaligned: "#d97706",
      slightly_aligned: "#c9a227",
      aligned: "#2f9e69",
      strongly_aligned: "#14764a",
      unscored: "#6c757d"
    }.freeze

    Row = Struct.new(
      :ability,
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
      :refreshable_ability_ids,
      :scoring_available?,
      keyword_init: true
    )

    def initialize(organization:, reference_time: Time.current)
      @organization = organization
      @reference_time = reference_time
    end

    def call
      rows = build_rows
      refreshable_rows = rows.select(&:refreshable?)
      refreshable_ids = refreshable_rows.map { |row| row.ability.id }

      Result.new(
        total_count: rows.size,
        scored_count: 0,
        missing_count: rows.size,
        stale_count: 0,
        refreshable_count: refreshable_ids.size,
        average_score: nil,
        distribution: distribution_for(rows),
        chart_data: chart_data_for(rows),
        best: [],
        worst: [],
        refreshable_rows: refreshable_rows,
        refreshable_ability_ids: refreshable_ids,
        scoring_available?: false
      )
    end

    private

    attr_reader :organization, :reference_time

    def abilities
      @abilities ||= Ability.unarchived.for_company(organization).ordered.to_a
    end

    def build_rows
      abilities.map do |ability|
        Row.new(
          ability: ability,
          score: nil,
          band: nil,
          calculated_at: nil,
          missing?: true,
          stale?: false,
          refreshable?: true
        )
      end
    end

    def distribution_for(rows)
      counts = Hash.new(0)
      rows.each do |row|
        key = row.band&.fetch(:key) || :unscored
        counts[key] += 1
      end

      bands = AssignmentSurveys::ExpectationAlignmentScore::SCORE_BANDS.map do |band|
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
            name: "Abilities",
            data: dist.map { |bucket| { y: bucket[:count], color: bucket[:color] } }
          }
        ]
      }
    end
  end
end
