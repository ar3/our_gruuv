# frozen_string_literal: true

module Insights
  # Y = aspirations; X = emp/mgr/final agreement on last finalized AspirationCheckIn.
  # Mirrors TalentDensity::AssignmentRatingAlignmentQuery classify/arrow semantics.
  class AspirationRatingAlignmentQuery
    AGREEMENT_COLUMNS = TalentDensity::AssignmentRatingAlignmentQuery::AGREEMENT_COLUMNS
    COLUMN_LABELS = TalentDensity::AssignmentRatingAlignmentQuery::COLUMN_LABELS

    Point = Struct.new(
      :teammate,
      :aspiration,
      :check_in,
      :agreement,
      :arrow,
      keyword_init: true
    )

    def initialize(teammates:, aspirations: nil)
      @teammates = Array(teammates)
      @aspirations = aspirations
    end

    def aspirations
      @aspirations_list ||= begin
        if @aspirations
          Array(@aspirations).sort_by { |a| [a.sort_order.to_i, a.name.to_s.downcase] }
        else
          placed.map(&:aspiration).uniq.sort_by { |a| [a.sort_order.to_i, a.name.to_s.downcase] }
        end
      end
    end

    def placed
      @placed ||= points.select { |point| AGREEMENT_COLUMNS.include?(point.agreement) }
    end

    def unplaced
      @unplaced ||= points.reject { |point| AGREEMENT_COLUMNS.include?(point.agreement) }
    end

    def cell(aspiration, agreement)
      placed.select { |point| point.aspiration.id == aspiration.id && point.agreement == agreement }
    end

    private

    def points
      @points ||= begin
        ids = @teammates.map(&:id)
        return [] if ids.empty?

        teammate_by_id = @teammates.index_by(&:id)
        aspiration_filter_ids = @aspirations&.map(&:id)
        latest_by_pair = {}

        scope = AspirationCheckIn
          .where(teammate_id: ids)
          .closed
          .where.not(official_rating: nil)
          .includes(:aspiration, company_teammate: :person)
          .order(official_check_in_completed_at: :desc, id: :desc)

        scope = scope.where(aspiration_id: aspiration_filter_ids) if aspiration_filter_ids

        scope.each do |check_in|
          key = [check_in.teammate_id, check_in.aspiration_id]
          latest_by_pair[key] ||= check_in
        end

        latest_by_pair.values.filter_map do |check_in|
          teammate = teammate_by_id[check_in.teammate_id]
          next unless teammate
          next unless check_in.aspiration

          agreement = TalentDensity::AssignmentRatingAlignmentQuery.classify(
            check_in.employee_rating,
            check_in.manager_rating,
            check_in.official_rating
          )
          Point.new(
            teammate: teammate,
            aspiration: check_in.aspiration,
            check_in: check_in,
            agreement: agreement,
            arrow: TalentDensity::AssignmentRatingAlignmentQuery.arrow_for(
              agreement,
              check_in.employee_rating,
              check_in.manager_rating,
              check_in.official_rating
            )
          )
        end
      end
    end
  end
end
