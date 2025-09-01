module PositionsHelper
  def milestone_level_display(level)
    case level
    when 1
      "Demonstrated"
    when 2
      "Advanced"
    when 3
      "Expert"
    when 4
      "Coach"
    when 5
      "Industry-Recognized"
    else
      "Unknown"
    end
  end

  def current_view_name
    case action_name
    when 'show'
      'Management View'
    when 'job_description'
      'Job Description View'
    else
      'Management View'
    end
  end
end
