# frozen_string_literal: true

module Organizations::SearchHelper
  def search_department_cell(record)
    department = record.department
    if department
      link_to(
        department.short_display_name,
        organization_department_path(@organization, department),
        class: 'text-decoration-none'
      )
    else
      content_tag(:span, 'No department', class: 'text-muted')
    end
  end
end
