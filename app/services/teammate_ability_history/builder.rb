# frozen_string_literal: true

module TeammateAbilityHistory
  # Visible calibration + milestone-award history rows for a teammate ability page.
  class Builder
    Entry = Struct.new(
      :kind,
      :sort_at,
      :calibration_item,
      :milestone_award,
      :view_role,
      :reveal_other_side,
      keyword_init: true
    )

    def self.call(...) = new(...).call

    def initialize(teammate:, ability:, viewer:, pundit_user:)
      @teammate = teammate
      @ability = ability
      @viewer = viewer
      @pundit_user = pundit_user
    end

    def call
      (calibration_entries + award_entries).sort_by { |entry| entry.sort_at || Time.at(0) }.reverse
    end

    private

    def calibration_entries
      calibration = @teammate.ability_milestone_calibration
      return [] if calibration.blank?
      return [] unless AbilityMilestoneCalibrationPolicy.new(@pundit_user, calibration).show?

      item = calibration.items.includes(:ability, :awarded_by_teammate).find_by(ability_id: @ability.id)
      return [] if item.blank?

      view_role = @viewer&.id == @teammate.id ? :employee : :manager
      [
        Entry.new(
          kind: :calibration,
          sort_at: calibration_sort_at(item),
          calibration_item: item,
          milestone_award: nil,
          view_role: view_role,
          reveal_other_side: item.both_rated?
        )
      ]
    end

    def award_entries
      awards = MilestoneAward
        .where(teammate_id: @teammate.id, ability_id: @ability.id)
        .includes(:certifying_teammate, :cosigning_teammate)
        .order(awarder_signed_at: :desc)

      awards.filter_map do |award|
        next unless MilestoneAwardPolicy.new(@pundit_user, award).view_award_attempt_history?

        Entry.new(
          kind: :milestone_award,
          sort_at: award.awarder_signed_at || award.created_at,
          calibration_item: nil,
          milestone_award: award,
          view_role: nil,
          reveal_other_side: false
        )
      end
    end

    def calibration_sort_at(item)
      [
        item.awarded_at,
        item.employee_rating_changed_at,
        item.manager_rating_changed_at,
        item.updated_at,
        item.created_at
      ].compact.max
    end
  end
end
