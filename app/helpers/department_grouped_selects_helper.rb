# frozen_string_literal: true

# Optgroups for MAAP object selects: Company-wide first, then departments A–Z;
# records sorted by display name within each group.
module DepartmentGroupedSelectsHelper
  def department_grouped_options_for_select(records, selected_id = nil, label_method: :name)
    return "" if records.blank?

    grouped = Array(records).group_by(&:department)
    ordered_keys = grouped.keys.sort_by { |dept| dept ? [1, dept.display_name.to_s.downcase] : [0, ""] }

    options = ordered_keys.map do |department|
      label =
        if department
          department_hierarchy_display(department).presence || department.display_name
        else
          "Company-wide"
        end
      choices = grouped[department]
                .sort_by { |record| record.public_send(label_method).to_s.downcase }
                .map { |record| [record.public_send(label_method), record.id] }
      [label, choices]
    end

    grouped_options_for_select(options, selected_id)
  end

  def assignments_grouped_options_for_select(assignments, selected_id = nil)
    department_grouped_options_for_select(assignments, selected_id, label_method: :title)
  end

  def abilities_grouped_options_for_select(abilities, selected_id = nil)
    department_grouped_options_for_select(abilities, selected_id, label_method: :name)
  end

  def titles_grouped_options_for_select(titles, selected_id = nil)
    department_grouped_options_for_select(titles, selected_id, label_method: :external_title)
  end

  def teams_grouped_options_for_select(teams, selected_id = nil)
    department_grouped_options_for_select(teams, selected_id, label_method: :display_name)
  end
end
