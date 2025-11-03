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
  
  def goal_category_label(goal)
    case goal.goal_category
    when :vision
      'Vision'
    when :objective
      'Objective'
    when :key_result
      'Key Result'
    when :bad_key_result
      'Bad Key Result'
    else
      goal.goal_type.humanize
    end
  end
  
  def goal_category_badge_class(goal)
    case goal.goal_category
    when :vision
      'bg-info'
    when :objective
      'bg-primary'
    when :key_result
      'bg-success'
    when :bad_key_result
      'bg-danger'
    else
      'bg-secondary'
    end
  end
  
  def goal_warning_class(goal)
    return 'table-danger' if goal.should_show_warning?
    ''
  end
  
  def goal_warning_message(goal)
    if goal.bad_key_result?
      "Bad Key Result: Key Results should have a due date"
    elsif goal.vision? && !goal.has_sub_goals?
      "Vision without sub-goals: Visions should have at least one related goal"
    elsif goal.objective? && !goal.has_sub_goals?
      "Objective without sub-goals: Objectives should have at least one key result"
    else
      "This goal has a problem"
    end
  end
  
  def timeframe_tooltip_text(goal)
    lines = []
    if goal.earliest_target_date.present?
      lines << "Earliest: #{goal.earliest_target_date.strftime('%B %d, %Y')}"
    else
      lines << "Earliest: Not set"
    end
    if goal.most_likely_target_date.present?
      lines << "Most Likely: #{goal.most_likely_target_date.strftime('%B %d, %Y')}"
    else
      lines << "Most Likely: Not set"
    end
    if goal.latest_target_date.present?
      lines << "Latest: #{goal.latest_target_date.strftime('%B %d, %Y')}"
    else
      lines << "Latest: Not set"
    end
    lines.join("\n")
  end
  
  def goal_privacy_rings(goal)
    case goal.privacy_level
    when 'only_creator'
      '🔘○○○'
    when 'only_creator_and_owner'
      '🔘🔘○○'
    when 'only_creator_owner_and_managers'
      '🔘🔘🔘○'
    when 'everyone_in_company'
      '🔘🔘🔘🔘'
    else
      '○○○○'
    end
  end
  
  def goal_privacy_label(goal)
    case goal.privacy_level
    when 'only_creator'
      'Creator Only'
    when 'only_creator_and_owner'
      'Creator & Owner'
    when 'only_creator_owner_and_managers'
      'Creator, Owner & Managers'
    when 'everyone_in_company'
      'Everyone in Company'
    else
      goal.privacy_level.humanize
    end
  end
  
  def goal_privacy_rings_with_label(goal)
    "#{goal_privacy_rings(goal)} #{goal_privacy_label(goal)}"
  end
  
  def goal_privacy_tooltip_text(goal)
    case goal.privacy_level
    when 'only_creator'
      'Only the creator can view this goal'
    when 'only_creator_and_owner'
      'The creator and owner can view this goal'
    when 'only_creator_owner_and_managers'
      'The creator, owner, and their managers can view this goal'
    when 'everyone_in_company'
      'Everyone in the company can view this goal'
    else
      goal.privacy_level.humanize
    end
  end
end


