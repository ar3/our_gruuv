module AboutMeHelper
  # Status indicator methods - return :red, :yellow, or :green
  
  def shareable_observations_status_indicator(teammate, organization)
    since_date = 30.days.ago
    
    # Observations given (published, not observer_only)
    given_count = Observation
      .where(observer: teammate.person, company: organization)
      .where.not(published_at: nil)
      .where.not(privacy_level: 'observer_only')
      .where('observed_at >= ?', since_date)
      .where(deleted_at: nil)
      .count
    
    # Observations received (published, not observer_only)
    teammate_ids = teammate.person.teammates.where(organization: organization).pluck(:id)
    received_count = Observation
      .joins(:observees)
      .where(observees: { teammate_id: teammate_ids })
      .where(company: organization)
      .where.not(published_at: nil)
      .where.not(privacy_level: 'observer_only')
      .where('observed_at >= ?', since_date)
      .where(deleted_at: nil)
      .distinct
      .count
    
    if given_count >= 1
      :green
    elsif given_count == 0 && received_count == 0
      :red
    else
      :yellow
    end
  end

  def goals_status_indicator(teammate)
    # Check if any goal (active or completed) completed in last 90 days
    completed_recently = Goal.for_teammate(teammate)
      .where('completed_at >= ?', 90.days.ago)
      .where(deleted_at: nil)
      .exists?
    
    if completed_recently
      return :green
    end
    
    all_goals = Goal.for_teammate(teammate).active.includes(:goal_check_ins)
    
    return :red if all_goals.empty?
    
    # Second path to green: all active goals have check-ins in past 2 weeks
    cutoff_week = (Date.current - 14.days).beginning_of_week(:monday)
    
    all_goals_have_recent_check_ins = all_goals.all? do |goal|
      goal.goal_check_ins.any? { |check_in| check_in.check_in_week_start >= cutoff_week }
    end
    
    if all_goals_have_recent_check_ins
      :green
    else
      :yellow
    end
  end

  def one_on_one_status_indicator(one_on_one_link)
    if one_on_one_link&.url.present?
      :green
    else
      :red
    end
  end

  def position_check_in_status_indicator(teammate)
    latest_finalized = PositionCheckIn.latest_finalized_for(teammate)
    
    return :yellow unless latest_finalized
    
    days_since = (Date.current - latest_finalized.official_check_in_completed_at.to_date).to_i
    
    if days_since > 90
      :red
    elsif days_since <= 90
      :green
    else
      :yellow
    end
  end

  def assignments_check_in_status_indicator(teammate, organization)
    active_tenure = teammate.active_employment_tenure
    
    return :yellow unless active_tenure&.position
    
    required_assignments = active_tenure.position.required_assignments.includes(:assignment)
    return :yellow if required_assignments.empty?
    
    cutoff_date = 90.days.ago
    
    all_recent = required_assignments.all? do |position_assignment|
      assignment = position_assignment.assignment
      latest_finalized = AssignmentCheckIn
        .where(teammate: teammate, assignment: assignment)
        .closed
        .order(official_check_in_completed_at: :desc)
        .first
      
      latest_finalized && latest_finalized.official_check_in_completed_at >= cutoff_date
    end
    
    none_recent = required_assignments.none? do |position_assignment|
      assignment = position_assignment.assignment
      latest_finalized = AssignmentCheckIn
        .where(teammate: teammate, assignment: assignment)
        .closed
        .order(official_check_in_completed_at: :desc)
        .first
      
      latest_finalized && latest_finalized.official_check_in_completed_at >= cutoff_date
    end
    
    if all_recent
      :green
    elsif none_recent
      :red
    else
      :yellow
    end
  end

  def aspirations_check_in_status_indicator(teammate, organization)
    company_aspirations = Aspiration.within_hierarchy(organization)
    return :yellow if company_aspirations.empty?
    
    cutoff_date = 90.days.ago
    
    all_recent = company_aspirations.all? do |aspiration|
      latest_finalized = AspirationCheckIn.latest_finalized_for(teammate, aspiration)
      latest_finalized && latest_finalized.official_check_in_completed_at >= cutoff_date
    end
    
    none_recent = company_aspirations.none? do |aspiration|
      latest_finalized = AspirationCheckIn.latest_finalized_for(teammate, aspiration)
      latest_finalized && latest_finalized.official_check_in_completed_at >= cutoff_date
    end
    
    if all_recent
      :green
    elsif none_recent
      :red
    else
      :yellow
    end
  end

  def abilities_status_indicator(teammate, organization)
    active_tenure = teammate.active_employment_tenure
    
    return :yellow unless active_tenure&.position
    
    required_assignments = active_tenure.position.required_assignments.includes(assignment: :assignment_abilities)
    return :yellow if required_assignments.empty?
    
    # Collect all required milestones
    all_required_milestones = []
    required_assignments.each do |position_assignment|
      assignment = position_assignment.assignment
      assignment.assignment_abilities.each do |assignment_ability|
        all_required_milestones << {
          ability: assignment_ability.ability,
          required_level: assignment_ability.milestone_level
        }
      end
    end
    
    return :yellow if all_required_milestones.empty?
    
    # Check teammate's current milestone for each required ability
    not_meeting_count = 0
    all_met = true
    
    all_required_milestones.each do |milestone_info|
      teammate_milestone = teammate.teammate_milestones.find_by(ability: milestone_info[:ability])
      current_level = teammate_milestone&.milestone_level || 0
      required_level = milestone_info[:required_level]
      
      if current_level < required_level
        not_meeting_count += 1
        all_met = false
      end
    end
    
    # Red if >50% not meeting
    if not_meeting_count > (all_required_milestones.count * 0.5)
      :red
    elsif all_met
      :green
    else
      :yellow
    end
  end

  def prompts_status_indicator(company_teammate)
    company = company_teammate.organization.root_company || company_teammate.organization
    
    # Get active prompts for the company
    active_prompts = PromptTemplate.where(company: company).available
    
    # If no active prompts, return nil (section will be hidden)
    return nil if active_prompts.empty?
    
    # Get user's prompts
    user_prompts = Prompt.where(company_teammate: company_teammate)
    
    # Check if user has any responses (non-empty text)
    # Use SQL to check for text that is not null and not empty
    has_responses = PromptAnswer
      .where(prompt: user_prompts)
      .where("text IS NOT NULL AND text != ''")
      .exists?
    
    # If no prompts or no responses, return red
    if user_prompts.empty? || !has_responses
      return :red
    end
    
    # Check if there's at least one active goal associated with any prompt
    prompt_ids = user_prompts.pluck(:id)
    has_active_goals = PromptGoal
      .where(prompt_id: prompt_ids)
      .joins(:goal)
      .merge(Goal.active)
      .exists?
    
    if has_active_goals
      :green
    else
      :yellow
    end
  end

  # Helper methods for displaying indicators
  def status_indicator_badge_class(status)
    case status
    when :red
      'text-danger'
    when :yellow
      'text-warning'
    when :green
      'text-success'
    else
      'text-muted'
    end
  end

  def status_indicator_icon(status)
    case status
    when :red
      'bi-x-circle-fill'
    when :yellow
      'bi-exclamation-circle-fill'
    when :green
      'bi-check-circle-fill'
    else
      'bi-circle'
    end
  end

  def status_indicator_alert_class(status)
    case status
    when :red
      'alert-danger'
    when :yellow
      'alert-warning'
    when :green
      'alert-success'
    else
      'alert-secondary'
    end
  end
end

