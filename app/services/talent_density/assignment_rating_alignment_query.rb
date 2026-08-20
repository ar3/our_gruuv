# frozen_string_literal: true

module TalentDensity
  # Y = assignments; X = emp/mgr/final agreement pattern on last finalized check-in.
  class AssignmentRatingAlignmentQuery
    RATING_RANK = {
      "working_to_meet" => 0,
      "meeting" => 1,
      "exceeding" => 2
    }.freeze

    AGREEMENT_COLUMNS = [
      :all_differed,
      :emp_mgr_same_final_differed,
      :emp_final_same_mgr_differed,
      :mgr_final_same_emp_differed,
      :all_same
    ].freeze

    COLUMN_LABELS = {
      all_same: "All three same",
      all_differed: "All three differed",
      emp_mgr_same_final_differed: "Emp+mgr same, final differed",
      emp_final_same_mgr_differed: "Emp+final same, mgr differed",
      mgr_final_same_emp_differed: "Mgr+final same, emp differed"
    }.freeze

    Point = Struct.new(
      :teammate,
      :assignment,
      :check_in,
      :agreement,
      :arrow,
      keyword_init: true
    )

    def initialize(teammates:)
      @teammates = Array(teammates)
    end

    def assignments
      @assignments ||= placed.map(&:assignment).uniq.sort_by { |assignment| assignment.title.to_s.downcase }
    end

    def placed
      @placed ||= points.select { |point| AGREEMENT_COLUMNS.include?(point.agreement) }
    end

    def unplaced
      @unplaced ||= points.reject { |point| AGREEMENT_COLUMNS.include?(point.agreement) }
    end

    def cell(assignment, agreement)
      placed.select { |point| point.assignment.id == assignment.id && point.agreement == agreement }
    end

    def self.classify(employee_rating, manager_rating, official_rating)
      emp = employee_rating.to_s.presence
      mgr = manager_rating.to_s.presence
      final = official_rating.to_s.presence
      return :incomplete if emp.blank? || mgr.blank? || final.blank?
      return :incomplete unless RATING_RANK.key?(emp) && RATING_RANK.key?(mgr) && RATING_RANK.key?(final)

      if emp == mgr && mgr == final
        :all_same
      elsif emp != mgr && emp != final && mgr != final
        :all_differed
      elsif emp == mgr && final != emp
        :emp_mgr_same_final_differed
      elsif emp == final && mgr != emp
        :emp_final_same_mgr_differed
      elsif mgr == final && emp != mgr
        :mgr_final_same_emp_differed
      else
        :incomplete
      end
    end

    def self.arrow_for(agreement, employee_rating, manager_rating, official_rating)
      case agreement
      when :all_same, :incomplete, nil
        nil
      when :all_differed, :emp_mgr_same_final_differed, :emp_final_same_mgr_differed
        compare_direction(official_rating, manager_rating)
      when :mgr_final_same_emp_differed
        compare_direction(official_rating, employee_rating)
      end
    end

    def self.compare_direction(left, right)
      left_rank = RATING_RANK[left.to_s]
      right_rank = RATING_RANK[right.to_s]
      return nil if left_rank.nil? || right_rank.nil? || left_rank == right_rank

      left_rank > right_rank ? :better : :worse
    end

    private

    def points
      @points ||= begin
        ids = @teammates.map(&:id)
        return [] if ids.empty?

        teammate_by_id = @teammates.index_by(&:id)
        latest_by_pair = {}

        AssignmentCheckIn
          .where(teammate_id: ids)
          .closed
          .where.not(official_rating: nil)
          .includes(:assignment, company_teammate: :person)
          .order(official_check_in_completed_at: :desc, id: :desc)
          .each do |check_in|
            key = [check_in.teammate_id, check_in.assignment_id]
            latest_by_pair[key] ||= check_in
          end

        latest_by_pair.values.filter_map do |check_in|
          teammate = teammate_by_id[check_in.teammate_id]
          next unless teammate
          next unless check_in.assignment

          agreement = self.class.classify(
            check_in.employee_rating,
            check_in.manager_rating,
            check_in.official_rating
          )
          Point.new(
            teammate: teammate,
            assignment: check_in.assignment,
            check_in: check_in,
            agreement: agreement,
            arrow: self.class.arrow_for(
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
