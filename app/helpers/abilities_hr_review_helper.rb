# frozen_string_literal: true

module AbilitiesHrReviewHelper
  def abilities_hr_milestone_option_label(level, ability_name:)
    n = level.to_i
    adjective = milestone_level_display(n)
    "Milestone #{n} – #{adjective} @ #{ability_name}"
  end

  def abilities_hr_join_milestone_select_options(ability_name:, selected:)
    options = (1..5).map do |level|
      [abilities_hr_milestone_option_label(level, ability_name: ability_name), level]
    end
    options_for_select(options, selected)
  end

  def abilities_hr_existing_assignment_ability_caption(assignment_id:, ability_id:, ability_name: nil)
    assignment_id = assignment_id.presence&.to_i
    ability_id = ability_id.presence&.to_i
    ability_name = ability_name.presence

    if assignment_id.blank? || ability_id.blank?
      return 'No association exists today.'
    end

    aa = AssignmentAbility.find_by(assignment_id: assignment_id, ability_id: ability_id)
    name = ability_name || Ability.find_by(id: ability_id)&.name || 'this ability'

    unless aa
      return "No association exists today between this assignment and #{name}."
    end

    level = aa.milestone_level
    adjective = milestone_level_display(level)
    "Existing today: Milestone #{level} – #{adjective} @ #{name}"
  end

  def abilities_hr_association_rows_sorted_by_assignment(rows, assignment_titles_by_id:)
    titles = assignment_titles_by_id.transform_keys(&:to_i)

    Array(rows).sort_by do |row|
      title = abilities_hr_assignment_sort_title(row, titles)
      [title.downcase, row['id'].to_s]
    end
  end

  def abilities_hr_assignment_sort_title(row, assignment_titles_by_id = {})
    id = row['resolved_assignment_id'].to_s.presence&.to_i
    if id.positive? && assignment_titles_by_id[id].present?
      assignment_titles_by_id[id].to_s
    else
      row['assignment_raw'].to_s.strip
    end
  end
end
