module AboutMeHelper
  # Status indicator methods - return :red, :yellow, or :green
  
  def shareable_observations_status_indicator(teammate, organization)
    # Use the same query logic as the view to ensure consistency
    query = AboutMeObservationsQuery.new(teammate, organization)
    
    given_count = query.observations_given.count
    received_count = query.observations_received.count
    
    if given_count == 0 && received_count == 0
      :red
    elsif (given_count >= 1 && received_count >= 1) || given_count >= 2
      :green
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

  # Returns the collection of assignments that should be shown in the about_me assignments section.
  # This includes:
  # 1. Required assignments from the teammate's current position
  # 2. Active assignment tenures with anticipated_energy_percentage > 0
  # 
  # This method ensures consistency across:
  # - The collapsed alert sentence
  # - The status indicator color
  # - The expanded assignment list
  # 
  # Note: Uses teammate.organization to ensure consistency with active_employment_tenure filtering
  def relevant_assignments_for_about_me(teammate, organization)
    active_tenure = teammate.active_employment_tenure
    
    # Get required assignments from position
    required_position_assignments = if active_tenure&.position
      active_tenure.position.required_assignments.includes(:assignment)
    else
      []
    end
    
    # Get active assignment tenures with anticipated energy > 0
    # Use teammate.organization to match the filtering in active_employment_tenure
    active_assignment_tenures = teammate.assignment_tenures
      .active_and_given_energy
      .includes(:assignment)
      .where(assignments: { company: teammate.organization })
    
    # Build a set of all relevant assignment IDs (required OR active with energy > 0)
    relevant_assignment_ids = Set.new
    required_position_assignments.each { |pa| relevant_assignment_ids.add(pa.assignment_id) }
    active_assignment_tenures.each { |at| relevant_assignment_ids.add(at.assignment_id) }
    
    # Return the assignments
    Assignment.where(id: relevant_assignment_ids.to_a).includes(:company)
  end

  def assignments_check_in_status_indicator(teammate, organization)
    relevant_assignments = relevant_assignments_for_about_me(teammate, organization)
    
    return :yellow if relevant_assignments.empty?
    
    cutoff_date = 90.days.ago
    # Convert to array to ensure we have the IDs
    relevant_assignment_ids = relevant_assignments.to_a.map(&:id)
    
    all_recent = relevant_assignment_ids.all? do |assignment_id|
      latest_finalized = AssignmentCheckIn
        .where(teammate: teammate, assignment_id: assignment_id)
        .closed
        .order(official_check_in_completed_at: :desc)
        .first
      
      latest_finalized && latest_finalized.official_check_in_completed_at >= cutoff_date
    end
    
    none_recent = relevant_assignment_ids.none? do |assignment_id|
      latest_finalized = AssignmentCheckIn
        .where(teammate: teammate, assignment_id: assignment_id)
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

  # Returns HTML content for popover explaining status conditions for each section
  def status_conditions_popover_content(section_type)
    case section_type
    when :stories
      content_tag(:div) do
        content_tag(:strong, "Stories Status Conditions:") +
        content_tag(:ul, class: "mb-0 mt-2") do
          content_tag(:li, content_tag(:span, "Red: ", class: "text-danger") + "No observations given or received in the past 30 days") +
          content_tag(:li, content_tag(:span, "Yellow: ", class: "text-warning") + "Only observations given OR only observations received (but not both)") +
          content_tag(:li, content_tag(:span, "Green: ", class: "text-success") + "Both observations given and received, OR 2+ observations given")
        end
      end
    when :goals
      content_tag(:div) do
        content_tag(:strong, "Active Goals Status Conditions:") +
        content_tag(:ul, class: "mb-0 mt-2") do
          content_tag(:li, content_tag(:span, "Red: ", class: "text-danger") + "No active goals") +
          content_tag(:li, content_tag(:span, "Yellow: ", class: "text-warning") + "Has active goals but not all have check-ins in the past 2 weeks") +
          content_tag(:li, content_tag(:span, "Green: ", class: "text-success") + "Any goal completed in last 90 days, OR all active goals have check-ins in past 2 weeks")
        end
      end
    when :prompts
      content_tag(:div) do
        content_tag(:strong, "Prompts Status Conditions:") +
        content_tag(:ul, class: "mb-0 mt-2") do
          content_tag(:li, content_tag(:span, "Red: ", class: "text-danger") + "No prompts started or no responses provided") +
          content_tag(:li, content_tag(:span, "Yellow: ", class: "text-warning") + "Has prompts with responses but no active goals associated") +
          content_tag(:li, content_tag(:span, "Green: ", class: "text-success") + "Has prompts with responses AND at least one active goal associated")
        end
      end
    when :one_on_one
      content_tag(:div) do
        content_tag(:strong, "1:1 Area Status Conditions:") +
        content_tag(:ul, class: "mb-0 mt-2") do
          content_tag(:li, content_tag(:span, "Red: ", class: "text-danger") + "No 1:1 link URL defined") +
          content_tag(:li, content_tag(:span, "Green: ", class: "text-success") + "1:1 link URL is present")
        end
      end
    when :position_check_in
      content_tag(:div) do
        content_tag(:strong, "Position/Overall Status Conditions:") +
        content_tag(:ul, class: "mb-0 mt-2") do
          content_tag(:li, content_tag(:span, "Yellow: ", class: "text-warning") + "No finalized check-in exists") +
          content_tag(:li, content_tag(:span, "Red: ", class: "text-danger") + "Last finalized check-in was more than 90 days ago") +
          content_tag(:li, content_tag(:span, "Green: ", class: "text-success") + "Last finalized check-in was within the last 90 days")
        end
      end
    when :assignments_check_in
      content_tag(:div) do
        content_tag(:strong, "Assignments/Outcomes Status Conditions:") +
        content_tag(:ul, class: "mb-0 mt-2") do
          content_tag(:li, content_tag(:span, "Yellow: ", class: "text-warning") + "No required assignments or active assignments with energy > 0") +
          content_tag(:li, content_tag(:span, "Red: ", class: "text-danger") + "None of the relevant assignments (required or active with energy > 0) have check-ins within the last 90 days") +
          content_tag(:li, content_tag(:span, "Green: ", class: "text-success") + "All relevant assignments (required or active with energy > 0) have check-ins within the last 90 days")
        end
      end
    when :aspirations_check_in
      content_tag(:div) do
        content_tag(:strong, "Aspirational Values Status Conditions:") +
        content_tag(:ul, class: "mb-0 mt-2") do
          content_tag(:li, content_tag(:span, "Yellow: ", class: "text-warning") + "No company aspirational values exist") +
          content_tag(:li, content_tag(:span, "Red: ", class: "text-danger") + "None of the company aspirational values have check-ins within the last 90 days") +
          content_tag(:li, content_tag(:span, "Green: ", class: "text-success") + "All company aspirational values have check-ins within the last 90 days")
        end
      end
    when :abilities
      content_tag(:div) do
        content_tag(:strong, "Abilities/Skills/Knowledge Status Conditions:") +
        content_tag(:ul, class: "mb-0 mt-2") do
          content_tag(:li, content_tag(:span, "Yellow: ", class: "text-warning") + "No position or no required assignments with ability milestones") +
          content_tag(:li, content_tag(:span, "Red: ", class: "text-danger") + "More than 50% of required ability milestones are not met") +
          content_tag(:li, content_tag(:span, "Green: ", class: "text-success") + "All required ability milestones are met")
        end
      end
    else
      ""
    end
  end
end

