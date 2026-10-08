# frozen_string_literal: true

module AbilityMilestoneCalibrationHelper
  RECENT_OGOS_LIMIT = 5

  def ability_milestone_calibration_entry_counts(teammate:, organization:)
    AbilityMilestoneCalibrationAbilitiesCatalog.entry_counts(teammate:, organization:)
  end

  def ability_milestone_calibration_entry_visible?(teammate:, organization:)
    calibration = teammate.ability_milestone_calibration || AbilityMilestoneCalibration.new(teammate: teammate)
    return false unless policy(calibration).entry_control?

    counts = ability_milestone_calibration_entry_counts(teammate:, organization:)
    counts[:full_set].positive?
  end

  def ability_milestone_calibration_rating_label(level)
    return 'Not answered' if level.nil?

    "Milestone #{level.to_i}"
  end

  def ability_milestone_calibration_source_label(source)
    level = source.milestone_level.to_i
    case source.kind.to_sym
    when :assignment_tenure
      "Assignment tenure: #{source.assignment.display_name} (requires Milestone #{level})"
    when :position_direct
      ctx = position_context_label(source.position_context)
      "Required directly by #{ctx} #{source.position.display_name} (Milestone #{level})"
    when :required_assignment
      ctx = position_context_label(source.position_context)
      "Required assignment on #{ctx} #{source.position.display_name}: " \
        "#{source.assignment.display_name} (Milestone #{level})"
    else
      "Requirement (Milestone #{level})"
    end
  end

  # Inline milestone copy for the Ability-details accordion (replaces popovers).
  # Milestone 0 copy (with Grow By Abilities CTA) is rendered in the accordion partial.
  def ability_milestone_calibration_milestone_details_html(ability, level, milestone_rec = nil)
    if level.nil?
      return tag.p('Not answered. No milestone proposal yet for this Ability.', class: 'small text-muted mb-0')
    end

    if level.to_i < 1
      return tag.p('No Milestone earned yet for this Ability.', class: 'small text-muted mb-0')
    end

    if milestone_rec.present?
      complete_picture_earned_milestone_popover_html(milestone_rec, ability)
    else
      complete_picture_unearned_milestone_popover_html(ability, level.to_i)
    end
  end

  def ability_milestone_calibration_rating_audit_lines(item, role:)
    return [] unless item.rated_for?(role)

    first_level = item.first_rating_for(role)
    first_at = item.first_rated_at_for(role)
    current = item.rating_for(role)
    changed_at = item.rating_changed_at_for(role)

    lines = []
    if first_level.present? && first_at.present?
      lines << "First: M#{first_level} · #{format_time_in_user_timezone(first_at)}"
    end

    if current.present? && changed_at.present?
      if first_level == current && first_at.present? && changed_at.to_i == first_at.to_i
        lines << "Last change: none (still M#{current})"
      else
        lines << "Last change: M#{current} · #{format_time_in_user_timezone(changed_at)}"
      end
    end

    lines
  end

  private

  def position_context_label(context)
    case context.to_s
    when 'target' then 'target position'
    else 'current position'
    end
  end
end
