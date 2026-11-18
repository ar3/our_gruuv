# frozen_string_literal: true

module Goals
  # Guards for auto-defaulting OG3 Progressive Outcome from a draft goal title.
  class ProgressiveOutcomeDefaultEligibility
    def self.eligible?(goal)
      new(goal).eligible?
    end

    def self.ineligibility_reasons(goal)
      new(goal).ineligibility_reasons
    end

    def self.title_has_enough_digits?(title)
      title.to_s.scan(/\d/).size > 1
    end

    def initialize(goal)
      @goal = goal
    end

    def eligible?
      ineligibility_reasons.empty?
    end

    def ineligibility_reasons
      reasons = []
      if @goal.blank?
        reasons << "goal missing"
        return reasons
      end

      reasons << "goal is deleted" if @goal.deleted_at.present?
      reasons << "goal is already started (started_at present)" if @goal.started_at.present?
      if @goal.goal_type.to_s == "inspirational_objective"
        reasons << "goal_type is inspirational_objective (objectives are never auto-converted)"
      end
      if @goal.outcome_fields_manually_edited_at.present?
        reasons << "outcome fields are manually locked"
      end
      if any_progressive_field_present?
        reasons << "one or more progressive fields already have values"
      end
      unless self.class.title_has_enough_digits?(@goal.title)
        reasons << "title has fewer than 2 digit characters (digit_chars=#{@goal.title.to_s.scan(/\d/).size})"
      end
      reasons
    end

    private

    def any_progressive_field_present?
      @goal.outcome_baseline.present? ||
        @goal.outcome_commit.present? ||
        @goal.outcome_stretch.present? ||
        @goal.outcome_transform.present? ||
        @goal.outcome_unit.present? ||
        @goal.progressive_current_aim.present?
    end
  end
end
