class EmploymentTenureDecorator < Draper::Decorator
  delegate_all

  def display_name
    "#{teammate.person.display_name} at #{company.display_name} (#{position.display_name})"
  end

  def status_badge
    if active?
      h.content_tag :span, 'Active', class: 'badge bg-success'
    else
      h.content_tag :span, 'Inactive', class: 'badge bg-secondary'
    end
  end

  def duration_display
    if ended_at.present?
      "#{started_at.strftime('%B %Y')} - #{ended_at.strftime('%B %Y')}"
    else
      "#{started_at.strftime('%B %Y')} - Present"
    end
  end

  def manager_display
    manager&.display_name || 'No manager assigned'
  end
end
