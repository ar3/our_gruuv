# frozen_string_literal: true

module Abilities
  # First emp/mgr milestone ratings for one Ability → agreement columns (Talent Density–style).
  # Pairs need both first ratings. Final (awarded official level) is optional; arrows only when final exists.
  class FirstRatingAlignmentQuery
    AGREEMENT_COLUMNS = [
      :emp_mgr_differed_no_final,
      :emp_mgr_same_no_final,
      :all_differed,
      :emp_mgr_same_final_differed,
      :emp_final_same_mgr_differed,
      :mgr_final_same_emp_differed,
      :all_same
    ].freeze

    COLUMN_LABELS = {
      emp_mgr_differed_no_final: "Emp+mgr differed (no final yet)",
      emp_mgr_same_no_final: "Emp+mgr same (no final yet)",
      all_differed: "All three differed",
      emp_mgr_same_final_differed: "Emp+mgr same, final differed",
      emp_final_same_mgr_differed: "Emp+final same, mgr differed",
      mgr_final_same_emp_differed: "Mgr+final same, emp differed",
      all_same: "All three same"
    }.freeze

    Point = Data.define(
      :item,
      :employee_first,
      :manager_first,
      :official,
      :has_final,
      :agreement,
      :arrow
    )

    def self.call(ability:)
      new(ability: ability).call
    end

    def initialize(ability:)
      @ability = ability
    end

    def call
      self
    end

    def points
      @points ||= load_points
    end

    def placed
      @placed ||= points.select { |point| AGREEMENT_COLUMNS.include?(point.agreement) }
    end

    def cell(agreement)
      placed.select { |point| point.agreement == agreement }
    end

    def empty?
      placed.empty?
    end

    def self.classify(employee_first, manager_first, official, has_final:)
      emp = integer_level(employee_first)
      mgr = integer_level(manager_first)
      return :incomplete if emp.nil? || mgr.nil?

      unless has_final
        return emp == mgr ? :emp_mgr_same_no_final : :emp_mgr_differed_no_final
      end

      final = integer_level(official)
      return :incomplete if final.nil?

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

    def self.arrow_for(agreement, employee_first, manager_first, official, has_final:)
      return nil unless has_final

      case agreement
      when :all_same, :incomplete, :emp_mgr_same_no_final, :emp_mgr_differed_no_final, nil
        nil
      when :all_differed, :emp_mgr_same_final_differed, :emp_final_same_mgr_differed
        compare_direction(official, manager_first)
      when :mgr_final_same_emp_differed
        compare_direction(official, employee_first)
      end
    end

    def self.compare_direction(left, right)
      left_rank = integer_level(left)
      right_rank = integer_level(right)
      return nil if left_rank.nil? || right_rank.nil? || left_rank == right_rank

      left_rank > right_rank ? :better : :worse
    end

    def self.integer_level(value)
      return nil if value.nil?

      n = value.to_i
      (0..5).cover?(n) ? n : nil
    end

    private

    def load_points
      AbilityMilestoneCalibrationItem
        .joins(:ability_milestone_calibration)
        .where(ability_id: @ability.id)
        .where.not(employee_first_rating: nil)
        .where.not(manager_first_rating: nil)
        .where(employee_first_rating: 1..5)
        .where(manager_first_rating: 1..5)
        .includes(ability_milestone_calibration: { company_teammate: :person })
        .filter_map { |item| point_for(item) }
    end

    def point_for(item)
      has_final = item.awarded?
      official = has_final ? item.official_milestone_level.to_i : nil
      agreement = self.class.classify(
        item.employee_first_rating,
        item.manager_first_rating,
        official,
        has_final: has_final
      )
      return nil unless AGREEMENT_COLUMNS.include?(agreement)

      arrow = self.class.arrow_for(
        agreement,
        item.employee_first_rating,
        item.manager_first_rating,
        official,
        has_final: has_final
      )

      Point.new(
        item: item,
        employee_first: item.employee_first_rating,
        manager_first: item.manager_first_rating,
        official: official,
        has_final: has_final,
        agreement: agreement,
        arrow: arrow
      )
    end
  end
end
