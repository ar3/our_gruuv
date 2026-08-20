# frozen_string_literal: true

module TalentDensity
  # Scatter actual finalized overall rating (X) vs assignment-energy guidance (Y).
  class GuidanceMatrixQuery
    X_RATINGS = VisualizationQuery::X_RATINGS
    Y_GUIDANCE_BOTTOM_TO_TOP = MyGrowth::ExperiencesSummary::GUIDANCE_RATINGS.freeze
    Y_GUIDANCE_TOP_TO_BOTTOM = Y_GUIDANCE_BOTTOM_TO_TOP.reverse.freeze

    GUIDANCE_TONE = {
      1 => "warning",
      2 => "primary",
      3 => "success"
    }.freeze

    Point = Struct.new(:teammate, :finalized, :guidance_rating, :summary, keyword_init: true)

    def initialize(teammates:)
      @teammates = Array(teammates)
    end

    def placed
      @placed ||= points.select { |point| placed?(point) }
    end

    def unplaced
      @unplaced ||= points.reject { |point| placed?(point) }
    end

    def cell(guidance_rating, actual_rating)
      placed.select do |point|
        point.guidance_rating == guidance_rating && point.finalized&.official_rating == actual_rating
      end
    end

    private

    def points
      @points ||= @teammates.map do |teammate|
        summary = MyGrowth::ExperiencesSummary.for_teammate(teammate)
        finalized = latest_finalized_for(teammate)
        Point.new(
          teammate: teammate,
          finalized: finalized,
          guidance_rating: summary.guidance_position_rating,
          summary: summary
        )
      end
    end

    def latest_finalized_for(teammate)
      @finalized_by_id ||= begin
        ids = @teammates.map(&:id)
        PositionCheckIn
          .where(teammate_id: ids)
          .closed
          .includes(finalized_by_teammate: :person)
          .order(official_check_in_completed_at: :desc)
          .group_by(&:teammate_id)
          .transform_values(&:first)
      end
      @finalized_by_id[teammate.id]
    end

    def placed?(point)
      GUIDANCE_TONE.key?(point.guidance_rating) && X_RATINGS.include?(point.finalized&.official_rating)
    end
  end
end
