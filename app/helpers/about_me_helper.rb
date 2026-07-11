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
    # Same scope as about_me goals section: only goals where teammate is the owner
    goals_owned = Goal.where(owner: teammate)

    # Check if any goal (active or completed) completed in last 90 days
    completed_recently = goals_owned
      .where('completed_at >= ?', 90.days.ago)
      .where(deleted_at: nil)
      .exists?

    if completed_recently
      return :green
    end

    all_goals = goals_owned.active.includes(:goal_check_ins)
    
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
    # Check if teammate has ever had any assignment check-in finalized
    has_any_finalized = AssignmentCheckIn.where(company_teammate: teammate).closed.exists?
    return :yellow unless has_any_finalized
    
    relevant_assignments = relevant_assignments_for_about_me(teammate, organization)
    
    return :yellow if relevant_assignments.empty?
    
    cutoff_date = 90.days.ago
    # Convert to array to ensure we have the IDs
    relevant_assignment_ids = relevant_assignments.to_a.map(&:id)
    
    all_recent = relevant_assignment_ids.all? do |assignment_id|
      latest_finalized = AssignmentCheckIn
        .where(company_teammate: teammate, assignment_id: assignment_id)
        .closed
        .order(official_check_in_completed_at: :desc)
        .first
      
      latest_finalized && latest_finalized.official_check_in_completed_at >= cutoff_date
    end
    
    none_recent = relevant_assignment_ids.none? do |assignment_id|
      latest_finalized = AssignmentCheckIn
        .where(company_teammate: teammate, assignment_id: assignment_id)
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
    # Check if teammate has ever had any aspiration check-in finalized
    has_any_finalized = AspirationCheckIn.where(company_teammate: teammate).closed.exists?
    return :yellow unless has_any_finalized
    
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

    position = active_tenure.position
    required_assignments = position.required_assignments.includes(assignment: :assignment_abilities)

    # Collect all required milestones (from assignments and position direct)
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
    position.position_abilities.includes(:ability).each do |position_ability|
      all_required_milestones << {
        ability: position_ability.ability,
        required_level: position_ability.milestone_level
      }
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

  def about_me_clarity_icon_details(eh_item:, casual_name:, object_name:, reference_time: Time.current)
    status = eh_item&.status || EngagementHealth::NEEDS_ATTENTION
    clarity_label = EngagementHealth::STATUS_LABELS.fetch(status, status.to_s.humanize)
    next_transition = about_me_next_clarity_transition(
      eh_item: eh_item,
      status: status,
      reference_time: reference_time
    )

    tooltip = if status == EngagementHealth::NEEDS_ATTENTION
      "#{casual_name} is #{clarity_label} on #{object_name}."
    else
      "#{casual_name} is #{clarity_label} on #{object_name}, however clarity will move to #{next_transition[:next_level]} in #{next_transition[:time_until]}."
    end
    tooltip += " You should consider checking in soon." unless status == EngagementHealth::HEALTHY

    {
      icon_class: about_me_clarity_icon_class(status),
      text_class: about_me_clarity_text_class(status),
      tooltip: tooltip,
      status: status,
      label: clarity_label
    }
  end

  def about_me_eh_item_for(type:, id: nil)
    EngagementHealth::UpNextSupport.find_item(
      @engagement_health_by_item_key || {},
      { type: type, id: id }
    )
  end

  def about_me_show_clarity_merge_row?(eh_item:, neither_side_ready:)
    neither_side_ready && eh_item&.status == EngagementHealth::HEALTHY
  end

  def about_me_clarity_merge_message(eh_item:, casual_name:, latest_finalized:, reference_time: Time.current)
    label = EngagementHealth::STATUS_LABELS.fetch(eh_item.status, eh_item.status.to_s.humanize)
    finalized_at = latest_finalized&.official_check_in_completed_at
    finalized_at ||= Time.zone.parse(eh_item.inputs["last_event_at"].to_s) if eh_item.inputs["last_event_at"].present?
    consider_at = if finalized_at.present?
      finalized_at + EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS.days
    else
      reference_time
    end
    window = if consider_at <= reference_time
      "less than a minute"
    else
      distance_of_time_in_words(reference_time, consider_at)
    end
    "#{casual_name} is #{label} and a new check-in should be considered in #{window}"
  end

  def about_me_goal_icon_details(has_active_goal:, latest_rating:, casual_name:, object_name:)
    if has_active_goal
      return {
        icon_class: 'bi-bullseye',
        text_class: 'text-success',
        tooltip: "#{casual_name} has an active goal linked to #{object_name}, which supports improving or sustaining this area."
      }
    end

    if latest_rating == 'working_to_meet'
      return {
        icon_class: 'bi-exclamation-diamond-fill',
        text_class: 'text-danger',
        tooltip: "#{casual_name} is working to meet on #{object_name}, but there is no active goal linked yet."
      }
    end

    {
      icon_class: 'bi-dash-circle',
      text_class: 'text-muted',
      tooltip: "#{casual_name} does not have an active goal linked to #{object_name}, and no goal is currently needed."
    }
  end

  def about_me_latest_check_in_rating(check_in)
    return nil unless check_in

    check_in.official_rating.presence || check_in.manager_rating.presence || check_in.employee_rating.presence
  end

  # Helper methods for displaying indicators
  def status_indicator_badge_class(status)
    case status
    when :red
      'text-danger'
    when :yellow, :warning
      'text-warning'
    when :green, :success
      'text-success'
    when :info
      'text-info'
    else
      'text-muted'
    end
  end

  def status_indicator_icon(status)
    case status
    when :red
      'bi-x-circle-fill'
    when :yellow, :warning
      'bi-exclamation-circle-fill'
    when :green, :success
      'bi-check-circle-fill'
    when :info
      'bi-info-circle-fill'
    else
      'bi-circle'
    end
  end

  def status_indicator_alert_class(status)
    case status
    when :red
      'alert-danger'
    when :yellow, :warning
      'alert-warning'
    when :green, :success
      'alert-success'
    when :info
      'alert-info'
    else
      'alert-secondary'
    end
  end

  def about_me_clarity_icon_class(status)
    case status
    when EngagementHealth::HEALTHY
      "bi-check-circle-fill"
    when EngagementHealth::WARNING
      "bi-exclamation-triangle-fill"
    else
      "bi-x-octagon-fill"
    end
  end

  def about_me_clarity_text_class(status)
    case status
    when EngagementHealth::HEALTHY
      "text-success"
    when EngagementHealth::WARNING
      "text-warning"
    else
      "text-danger"
    end
  end

  def about_me_next_clarity_transition(eh_item:, status:, reference_time:)
    finalized_at = nil
    if eh_item&.inputs&.dig("last_event_at").present?
      finalized_at = Time.zone.parse(eh_item.inputs["last_event_at"].to_s) rescue nil
    end
    return { next_level: EngagementHealth::STATUS_LABELS.fetch(EngagementHealth::NEEDS_ATTENTION), time_until: "less than a minute" } if finalized_at.blank?

    transition_at, next_level = case status
    when EngagementHealth::HEALTHY
      [
        finalized_at + (EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS + 1).days,
        EngagementHealth::STATUS_LABELS.fetch(EngagementHealth::WARNING)
      ]
    when EngagementHealth::WARNING
      [
        finalized_at + EngagementHealth::Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS.days,
        EngagementHealth::STATUS_LABELS.fetch(EngagementHealth::NEEDS_ATTENTION)
      ]
    else
      [reference_time, EngagementHealth::STATUS_LABELS.fetch(EngagementHealth::NEEDS_ATTENTION)]
    end

    time_until = if transition_at <= reference_time
      "less than a minute"
    else
      distance_of_time_in_words(reference_time, transition_at)
    end

    { next_level: next_level, time_until: time_until }
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
          content_tag(:li, content_tag(:span, "Yellow: ", class: "text-warning") + "No assignment check-in has ever been finalized, OR no required assignments or active assignments with energy > 0") +
          content_tag(:li, content_tag(:span, "Red: ", class: "text-danger") + "None of the relevant assignments (required or active with energy > 0) have check-ins within the last 90 days") +
          content_tag(:li, content_tag(:span, "Green: ", class: "text-success") + "All relevant assignments (required or active with energy > 0) have check-ins within the last 90 days")
        end
      end
    when :aspirations_check_in
      content_tag(:div) do
        content_tag(:strong, "Aspirational Values Status Conditions:") +
        content_tag(:ul, class: "mb-0 mt-2") do
          content_tag(:li, content_tag(:span, "Yellow: ", class: "text-warning") + "No aspiration check-in has ever been finalized, OR no company aspirational values exist") +
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

  # Start Here About Me widget: human-readable section names grouped by status (same rules as About Me / digest).
  def about_me_section_names_by_status(teammate, organization)
    return { green: [], yellow: [], red: [] } unless teammate && organization

    service = Digest::AboutMeContentService.new(teammate: teammate, organization: organization)
    sections = service.sections
    {
      green: sections.select { |s| s[:status] == :green }.map { |s| s[:section_name] },
      yellow: sections.select { |s| s[:status] == :yellow }.map { |s| s[:section_name] },
      red: sections.select { |s| s[:status] == :red }.map { |s| s[:section_name] }
    }
  end
end

