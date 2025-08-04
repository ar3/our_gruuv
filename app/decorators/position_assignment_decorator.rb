class PositionAssignmentDecorator < Draper::Decorator
  delegate_all

  def display_title
    title = assignment.title
    
    if energy_range_display != "No effort estimate"
      "#{title} (#{energy_range_display})"
    else
      title
    end
  end

  def display_title_with_type
    "#{assignment.title} (#{assignment_type.humanize})"
  end

  def display_title_with_energy
    title = assignment.title
    energy = energy_range_display
    
    if energy != "No effort estimate"
      "#{title} - #{energy}"
    else
      title
    end
  end
end 