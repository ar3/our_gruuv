module GoalsHelper
  def goal_badge_class(goal_type)
    case goal_type
    when 'inspirational_objective'
      'bg-primary'
    when 'qualitative_key_result'
      'bg-info'
    when 'quantitative_key_result'
      'bg-success'
    else
      'bg-secondary'
    end
  end
  
  def timeframe_badge_class(timeframe)
    case timeframe
    when :now
      'bg-danger'
    when :next
      'bg-warning'
    when :later
      'bg-secondary'
    else
      'bg-secondary'
    end
  end
  
  def status_badge_class(status)
    case status
    when :draft
      'bg-secondary'
    when :active
      'bg-success'
    when :completed
      'bg-primary'
    when :cancelled
      'bg-danger'
    else
      'bg-secondary'
    end
  end
end

