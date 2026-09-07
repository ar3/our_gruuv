# frozen_string_literal: true

module AbilityMilestoneCalibrationHelper
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
    return 'Not answered' if level.nil? || level.to_i < 1

    "Milestone #{level.to_i}"
  end

  def ability_milestone_calibration_ability_description_popover_html(ability)
    if ability.description.present?
      tag.div(class: 'text-start markdown-content small') { render_markdown(ability.description) }
    else
      tag.p('No ability description.', class: 'small text-muted mb-0')
    end
  end

  # Proposal levels are 1–5. Official award may still use 0 (= leave unawarded / not answered).
  def ability_milestone_calibration_milestone_popover_html(ability, level, milestone_rec = nil)
    if level.nil? || level.to_i < 1
      return tag.div(class: 'small text-muted text-start') do
        'Not answered (M0). No milestone proposal or award for this ability yet.'
      end
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

  def ability_milestone_calibration_milestones_index(teammate, items)
    ability_ids = Array(items).map(&:ability_id)
    return {} if ability_ids.empty?

    teammate.teammate_milestones.where(ability_id: ability_ids).index_by { |m| [m.ability_id, m.milestone_level] }
  end
end
