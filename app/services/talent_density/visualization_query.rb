# frozen_string_literal: true

module TalentDensity
  class VisualizationQuery
    X_RATINGS = [-3, -2, -1, 1, 2, 3].freeze
    Y_STANCES_BOTTOM_TO_TOP = %w[take_the_swap fine_either_way try_to_avoid_the_swap].freeze
    Y_STANCES_TOP_TO_BOTTOM = Y_STANCES_BOTTOM_TO_TOP.reverse.freeze

    Point = Struct.new(:teammate, :stance, :last_entry, :stance_version, :finalized, keyword_init: true)

    def initialize(teammates:, period_month: TalentDensityStance.current_period_month)
      @teammates = Array(teammates)
      @period_month = period_month.to_date.beginning_of_month
    end

    def placed
      @placed ||= points.select { |point| placed?(point) }
    end

    def unplaced
      @unplaced ||= points.reject { |point| placed?(point) }
    end

    def cell(stance_key, rating)
      placed.select { |point| point.stance&.stance == stance_key.to_s && point.finalized&.official_rating == rating }
    end

    private

    def points
      @points ||= begin
        ids = @teammates.map(&:id)
        # Viz selection uses only the current period — never falls back to a prior month.
        current_by_id = TalentDensityStance.for_period(@period_month)
          .where(company_teammate_id: ids)
          .includes(:stance_set_by)
          .index_by(&:company_teammate_id)
        last_by_id = TalentDensityStance.latest_by_teammate_id(ids)
        versions_by_stance_id = latest_versions_by_stance_id(current_by_id.values.map(&:id))
        finalized_by_id = PositionCheckIn
          .where(teammate_id: ids)
          .closed
          .includes(finalized_by_teammate: :person)
          .order(official_check_in_completed_at: :desc)
          .group_by(&:teammate_id)
          .transform_values(&:first)

        @teammates.map do |teammate|
          stance = current_by_id[teammate.id]
          Point.new(
            teammate: teammate,
            stance: stance,
            last_entry: last_by_id[teammate.id],
            stance_version: stance && versions_by_stance_id[stance.id],
            finalized: finalized_by_id[teammate.id]
          )
        end
      end
    end

    def placed?(point)
      point.stance&.stance.present? && X_RATINGS.include?(point.finalized&.official_rating)
    end

    def latest_versions_by_stance_id(stance_ids)
      return {} if stance_ids.empty?

      PaperTrail::Version
        .where(item_type: "TalentDensityStance", item_id: stance_ids)
        .order(created_at: :desc, id: :desc)
        .group_by(&:item_id)
        .transform_values(&:first)
    end
  end
end
