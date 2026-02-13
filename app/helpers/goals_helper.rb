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

  def goal_no_check_in_access_tooltip(goal)
    if goal.owner_type == 'CompanyTeammate'
      "Only the goal creator or owner can add check-ins to this goal."
    else
      "You don't have permission to add check-ins to this goal."
    end
  end

  def goal_no_edit_access_tooltip(_goal)
    "Only the goal creator or owner can edit this goal."
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

  # For hierarchical goal index: "no due date" | "due in X" | "due X ago"
  def goal_index_due_phrase(goal)
    date = goal.calculated_target_date
    return "no due date" if date.blank?
    today = Date.current
    if date < today
      "due #{time_ago_in_words(date)} ago"
    elsif date > today
      "due in #{distance_of_time_in_words(today, date)}"
    else
      "due today"
    end
  end

  # Sentence for hierarchical goal index: <status> | <goal type> | <due phrase>. Draft gets warning color + icon. Due shows popover with earliest/most likely/latest when present.
  def goal_index_info_sentence(goal)
    status_word = goal.status.to_s.humanize
    status_span = if goal.status == :draft
      content_tag(:span, class: 'text-warning') do
        content_tag(:i, '', class: 'bi bi-exclamation-triangle me-1', 'aria-hidden': 'true') + status_word
      end
    else
      content_tag(:span, status_word, class: '')
    end
    type_span = content_tag(:span, goal_category_label(goal), class: '')
    due_phrase = goal_index_due_phrase(goal)
    due_span = if goal_index_due_phrase_has_dates?(goal)
      popover_content = timeframe_tooltip_text(goal).gsub("\n", '<br>')
      content_tag(:span, due_phrase, class: '', style: 'cursor: pointer;',
        'data-bs-toggle' => 'popover', 'data-bs-trigger' => 'hover', 'data-bs-placement' => 'top',
        'data-bs-html' => 'true', 'data-bs-content' => popover_content)
    else
      content_tag(:span, due_phrase, class: '')
    end
    safe_join([status_span, type_span, due_span], ' | ')
  end

  def goal_index_due_phrase_has_dates?(goal)
    goal.earliest_target_date.present? || goal.most_likely_target_date.present? || goal.latest_target_date.present?
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

  # Standardized visibility display: "Visible to: 🔘🔘🔘○" with tooltip
  # Use this for dense/moderate density views (tables, lists, cards)
  def goal_visibility_display(goal)
    "Visible to: #{goal_privacy_rings(goal)}"
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

  def goal_privacy_badge_class(goal)
    case goal.privacy_level
    when 'only_creator'
      'bg-dark'
    when 'only_creator_and_owner'
      'bg-danger'
    when 'only_creator_owner_and_managers'
      'bg-warning text-dark'
    when 'everyone_in_company'
      'bg-light text-dark border'
    else
      'bg-secondary'
    end
  end

  def goal_privacy_icon(goal)
    case goal.privacy_level
    when 'only_creator'
      'bi-lock-fill'
    when 'only_creator_and_owner'
      'bi-person-lock'
    when 'only_creator_owner_and_managers'
      'bi-people'
    when 'everyone_in_company'
      'bi-globe'
    else
      'bi-shield'
    end
  end
  
  def prepare_visualization_data(goals)
    goal_ids = goals.pluck(:id)
    
    # Load goals with associations
    goals_with_associations = goals.includes(:outgoing_links, :incoming_links, :owner, :creator, :company)
    
    # Get all links involving these goals (both directions)
    links = GoalLink.where(parent_id: goal_ids)
                    .or(GoalLink.where(child_id: goal_ids))
                    .includes(:parent, :child)
    
    # Build category map
    categories = goals_with_associations.map { |g| [g.id, g.goal_category] }.to_h
    
    {
      goals: goals_with_associations,
      links: links,
      categories: categories
    }
  end
  
  def render_tree_node(goal, depth, parent_child_map, categories, organization)
    children = parent_child_map[goal.id] || []
    category = categories[goal.id]
    badge_class = case category
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
    
    html = content_tag(:div, class: 'tree-node', style: "margin-left: #{depth * 40}px; margin-bottom: 10px;") do
      content_tag(:div, class: 'd-flex align-items-center') do
        arrow = depth > 0 ? content_tag(:i, '', class: 'bi bi-arrow-return-right me-2', style: 'color: #999;') : ''.html_safe
        card_content = content_tag(:div, class: 'card', style: 'min-width: 300px; max-width: 500px;') do
          content_tag(:div, class: 'card-body p-2') do
            content_tag(:div, class: 'd-flex align-items-center justify-content-between') do
              left = content_tag(:div, class: 'flex-grow-1') do
                safe_join([
                  link_to(goal.title, organization_goal_path(organization, goal), class: 'text-decoration-none fw-bold'),
                  tag(:br),
                  content_tag(:span, goal_category_label(goal), class: "badge #{badge_class}", style: 'font-size: 0.7em;')
                ])
              end
              right = children.any? ? content_tag(:span, pluralize(children.count, 'child'), class: 'badge bg-light text-dark') : ''.html_safe
              safe_join([left, right])
            end
          end
        end
        safe_join([arrow, card_content])
      end
    end
    
    children_html = children.map { |child| render_tree_node(child, depth + 1, parent_child_map, categories, organization) }
    
    safe_join([html] + children_html)
  end
  
  def render_nested_goal(goal, depth, parent_child_map, categories, organization)
    children = parent_child_map[goal.id] || []
    category = categories[goal.id]
    badge_class = case category
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
    
    border_color = case category
    when :vision
      '#17a2b8'
    when :objective
      '#007bff'
    when :key_result
      '#28a745'
    when :bad_key_result
      '#dc3545'
    else
      '#6c757d'
    end
    
    html = content_tag(:div, class: 'nested-goal-card', style: "margin-left: #{depth * 30}px; margin-bottom: 15px; border-left: 4px solid #{border_color};") do
      card = content_tag(:div, class: 'card', style: "background: #{depth == 0 ? '#fff' : '#f8f9fa'};") do
        content_tag(:div, class: 'card-body') do
          content_tag(:div, class: 'd-flex align-items-center justify-content-between') do
            left = content_tag(:div, class: 'flex-grow-1') do
              link_to(goal.title, organization_goal_path(organization, goal), class: 'text-decoration-none fw-bold') +
              tag(:br) +
              content_tag(:span, goal_category_label(goal), class: "badge #{badge_class}", style: 'font-size: 0.7em; margin-top: 5px;')
            end
            right = children.any? ? content_tag(:span, pluralize(children.count, 'child'), class: 'badge bg-light text-dark') : ''
            left + right
          end
        end
      end
      
      children_html = if children.any?
        content_tag(:div, class: 'nested-children', style: 'margin-top: 10px;') do
          children.map { |child| render_nested_goal(child, depth + 1, parent_child_map, categories, organization) }.join.html_safe
        end
      else
        ''
      end
      
      card + children_html
    end
    
    html
  end
  
  def confidence_percentage_options
    options = []
    (5..95).step(5).each do |percent|
      options << ["#{percent}%", percent]
    end
    options
  end
  
  def current_week_start
    Date.current.beginning_of_week(:monday)
  end
  
  def current_week_range
    start = current_week_start
    finish = start.end_of_week(:sunday)
    "#{start.strftime('%a, %b %d')} - #{finish.strftime('%a, %b %d, %Y')}"
  end
  
  def goal_check_in_tooltip_content(check_in)
    lines = []
    lines << "<strong>Week:</strong> #{check_in.week_display}"
    lines << "<strong>Confidence:</strong> #{check_in.confidence_percentage}%"
    if check_in.confidence_reason.present?
      lines << "<strong>Reason:</strong> #{check_in.confidence_reason}"
    end
    lines << "<strong>Reported by:</strong> #{check_in.confidence_reporter.display_name}"
    lines.join('<br>')
  end
  
  def goal_current_view_name(current_mode = nil)
    # If current_mode is not provided, fall back to action_name for backward compatibility
    mode = current_mode || (action_name == 'show' ? :view : (action_name == 'edit' ? :edit : (action_name == 'weekly_update' ? :check_in : :view)))
    
    case mode
    when :view
      'View Mode'
    when :edit
      'Edit Mode'
    when :check_in
      'Check-in Mode'
    else
      'View Mode' # Default
    end
  end
  
  def render_hierarchical_indented_goal(goal, depth, parent_child_map, organization, most_recent_check_ins_by_goal = {})
    children = (parent_child_map[goal.id] || []).compact
    indent_px = depth * 30
    warning_class = goal_warning_class(goal)
    border_style = depth > 0 ? 'border-left: 2px solid #dee2e6; padding-left: 15px;' : ''
    most_recent_check_in = most_recent_check_ins_by_goal[goal.id]
    
    html = content_tag(:div, class: "list-group-item #{warning_class}", style: "margin-left: #{indent_px}px; #{border_style}") do
      content_tag(:div, class: 'd-flex w-100 justify-content-between align-items-start') do
        flex_grow = content_tag(:div, class: 'flex-grow-1') do
          title = content_tag(:h5, class: 'mb-1') do
            link_to(goal.title, organization_goal_path(organization, goal), class: 'text-decoration-none') +
            content_tag(:span, goal_category_label(goal), class: "badge ms-2 #{goal_category_badge_class(goal)}") +
            (goal.should_show_warning? ? content_tag(:i, '', class: 'bi bi-exclamation-triangle text-warning ms-1', 'data-bs-toggle': 'tooltip', 'data-bs-title': goal_warning_message(goal)) : '')
          end
          badges = content_tag(:p, class: 'mb-1') do
            owned_by_span = content_tag(:span, " | Owned by: #{goal_owner_display_name(goal)}", class: 'text-muted small ms-2')
            prompt_span = if goal.prompt_goals.any?
              link_to(" | #{goal_prompt_association_display(goal)}", edit_organization_prompt_path(organization, goal.prompt_goals.first.prompt), target: '_blank', rel: 'noopener', class: 'text-muted small ms-2 text-decoration-none')
            else
              ''
            end
            content_tag(:span, goal.timeframe.to_s.humanize, class: "badge me-2 #{timeframe_badge_class(goal.timeframe)}", 'data-bs-toggle': 'tooltip', 'data-bs-title': timeframe_tooltip_text(goal)) +
            content_tag(:span, goal.status.to_s.humanize, class: "badge me-2 #{status_badge_class(goal.status)}") +
            content_tag(:span, goal_visibility_display(goal), class: 'text-muted small ms-2', 'data-bs-toggle': 'tooltip', 'data-bs-title': goal_privacy_tooltip_text(goal)) +
            owned_by_span + prompt_span
          end
          check_in_sentence = ''
          if most_recent_check_in.present?
            check_in_sentence = content_tag(:p, class: 'mb-1 small text-muted') do
              render 'organizations/goals/goal_check_in_sentence', check_in: most_recent_check_in, goal: goal
            end
          end
          title + badges + check_in_sentence
        end
        actions = content_tag(:div, class: 'ms-3') do
          start_button = ''.html_safe
          if goal.started_at.nil? && policy(goal)&.update?
            start_button = button_to(start_organization_goal_path(organization, goal), method: :patch, class: 'btn btn-primary btn-sm me-2', form: { style: 'display: inline-block;' }) do
              content_tag(:i, '', class: 'bi bi-play-circle me-1') + 'Start'.html_safe
            end
          end
          view_button = link_to(organization_goal_path(organization, goal), class: 'btn btn-outline-primary btn-sm') do
            content_tag(:i, '', class: 'bi bi-eye')
          end
          start_button + view_button
        end
        flex_grow + actions
      end
    end
    
    children_html = children.map { |child| render_hierarchical_indented_goal(child, depth + 1, parent_child_map, organization, most_recent_check_ins_by_goal) }.join.html_safe
    
    (html + children_html).html_safe
  end
  
  
  def calculate_goals_overview_stats(goals)
    stats = {
      visions_now: 0,
      visions_not_started: 0,
      objectives_now: 0,
      objectives_next: 0,
      objectives_later: 0,
      objectives_not_started: 0,
      outcomes_now: 0,
      outcomes_next: 0,
      outcomes_later: 0,
      outcomes_not_started: 0,
      stepping_stones_now: 0,
      stepping_stones_next: 0,
      stepping_stones_later: 0,
      stepping_stones_not_started: 0
    }
    
    goals.each do |goal|
      # Visions: inspirational_objective with no due date
      if goal.goal_type == 'inspirational_objective' && goal.most_likely_target_date.nil?
        if goal.started_at.present?
          stats[:visions_now] += 1
        else
          stats[:visions_not_started] += 1
        end
      # Objectives: inspirational_objective with due date
      elsif goal.goal_type == 'inspirational_objective' && goal.most_likely_target_date.present?
        if goal.started_at.nil?
          stats[:objectives_not_started] += 1
        else
          timeframe = goal.timeframe
          case timeframe
          when :now
            stats[:objectives_now] += 1
          when :next
            stats[:objectives_next] += 1
          when :later
            stats[:objectives_later] += 1
          end
        end
      # Outcomes: qualitative or quantitative key results
      elsif goal.goal_type.in?(['qualitative_key_result', 'quantitative_key_result'])
        if goal.most_likely_target_date.nil? || goal.started_at.nil?
          stats[:outcomes_not_started] += 1
        else
          timeframe = goal.timeframe
          case timeframe
          when :now
            stats[:outcomes_now] += 1
          when :next
            stats[:outcomes_next] += 1
          when :later
            stats[:outcomes_later] += 1
          end
        end
      # Stepping Stones: stepping_stone_activity
      elsif goal.goal_type == 'stepping_stone_activity'
        if goal.started_at.nil? || goal.most_likely_target_date.nil?
          stats[:stepping_stones_not_started] += 1
        else
          timeframe = goal.timeframe
          case timeframe
          when :now
            stats[:stepping_stones_now] += 1
          when :next
            stats[:stepping_stones_next] += 1
          when :later
            stats[:stepping_stones_later] += 1
          end
        end
      end
    end
    
    stats
  end
  
  def goal_owner_display_name(goal)
    return 'Unknown' unless goal.owner

    if goal.owner_type == 'CompanyTeammate'
      goal.owner.person&.display_name || 'Unknown'
    elsif goal.owner_type.in?(['Company', 'Department', 'Team', 'Organization'])
      goal.owner.display_name || goal.owner.name || 'Unknown'
    else
      'Unknown'
    end
  end

  # Returns a short phrase when the goal is associated to one or more prompts (e.g. "In reflection: Weekly Check-in"), or nil.
  def goal_prompt_association_display(goal)
    return nil if goal.prompt_goals.blank?

    titles = goal.prompt_goals.map { |pg| pg.prompt.prompt_template.title }.uniq
    return nil if titles.empty?

    reflection_label = company_label_for('reflection', 'Reflection')
    "In #{reflection_label.downcase}: #{titles.join(', ')}"
  end
  
  # Returns the owner's profile image or organization initials, wrapped with a tooltip showing the full owner name
  # For CompanyTeammate owners: shows their profile image or initials
  # For Organization owners: shows organization initials
  def goal_owner_image(goal, size: 48)
    inner = goal_owner_image_content(goal, size: size)
    tooltip_title = goal_owner_display_name(goal)
    content_tag :span,
                inner,
                'data-bs-toggle': 'tooltip',
                'data-bs-title': tooltip_title,
                title: tooltip_title
  end

  # Inner content for goal owner image (avatar or initials). Use goal_owner_image for the version with tooltip.
  def goal_owner_image_content(goal, size: 48)
    return organization_initials_circle('?', size: size) unless goal.owner

    if goal.owner_type == 'CompanyTeammate'
      teammate = goal.owner
      profile_url = teammate.profile_image_url

      if profile_url.present?
        image_tag profile_url,
                  class: "rounded-circle",
                  style: "width: #{size}px; height: #{size}px; object-fit: cover;",
                  alt: teammate.person&.display_name || 'Owner'
      else
        # Fallback to person initials
        initials = teammate.person&.first_name&.first&.upcase || teammate.person&.email&.first&.upcase || '?'
        content_tag :div,
                    class: "bg-primary rounded-circle d-flex align-items-center justify-content-center text-white",
                    style: "width: #{size}px; height: #{size}px;" do
          content_tag :span, initials, class: "fw-bold", style: "font-size: #{size * 0.4}px;"
        end
      end
    elsif goal.owner_type.in?(['Company', 'Department', 'Team', 'Organization'])
      org = goal.owner
      # Get initials from organization name (first letter of each word, max 2)
      name = org.display_name || org.name || 'Org'
      initials = name.split(/\s+/).map(&:first).take(2).join.upcase
      initials = 'O' if initials.blank?
      organization_initials_circle(initials, size: size)
    else
      organization_initials_circle('?', size: size)
    end
  end
  
  # Helper to render organization initials in a colored circle
  def organization_initials_circle(initials, size: 48)
    content_tag :div,
                class: "bg-secondary rounded-circle d-flex align-items-center justify-content-center text-white",
                style: "width: #{size}px; height: #{size}px;" do
      content_tag :span, initials, class: "fw-bold", style: "font-size: #{size * 0.4}px;"
    end
  end

  def goal_is_completed?(goal)
    goal.completed_at.present?
  end
  
  def goal_completion_outcome(goal)
    return nil unless goal_is_completed?(goal)
    
    last_check_in = goal.goal_check_ins.recent.first
    return nil unless last_check_in
    
    if last_check_in.confidence_percentage == 100
      # Check if completed late
      if goal.most_likely_target_date.present? && goal.completed_at.to_date > goal.most_likely_target_date
        :hit_late
      else
        :hit
      end
    elsif last_check_in.confidence_percentage == 0
      :miss
    else
      nil
    end
  end
  
  def goal_status_icon(goal)
    return 'bi-tools' unless goal_is_completed?(goal)
    
    last_check_in = goal.goal_check_ins.recent.first
    return 'bi-tools' unless last_check_in
    
    if last_check_in.confidence_percentage == 100
      'bi-check-circle'
    elsif last_check_in.confidence_percentage == 0
      'bi-x-circle'
    else
      'bi-tools'
    end
  end
  
  def goal_should_be_struck_through?(goal)
    return false unless goal_is_completed?(goal)
    
    last_check_in = goal.goal_check_ins.recent.first
    return false unless last_check_in
    
    last_check_in.confidence_percentage == 100
  end
  
  def goal_completion_badge_text(goal)
    outcome = goal_completion_outcome(goal)
    return nil unless outcome
    
    case outcome
    when :hit
      'Hit'
    when :hit_late
      'Hit (Late)'
    when :miss
      'Missed'
    else
      nil
    end
  end
  
  def child_goal_action_button(goal)
    if goal.needs_target_date?
      { type: 'fix', text: 'Fix Goal', class: 'btn-danger' }
    elsif goal.needs_start?
      { type: 'start', text: 'Start', class: 'btn-primary' }
    else
      nil
    end
  end

  # Options for the reusable on-track pill (shared/_on_track_pill). Returns nil when status is :na.
  # status: :good_green (dark green), :green (light green), :yellow, :red
  def on_track_pill_options(status)
    return nil if status.blank? || status == :na

    label = status == :red ? 'Off Track' : 'On Track'
    case status
    when :good_green
      { label: label, style: 'background-color: #198754;', class: 'ms-1' }
    when :green
      { label: label, style: 'background-color: #a3cfbb; color: #0f5132;', class: 'ms-1' }
    when :yellow
      { label: label, style: nil, class: 'bg-warning text-dark ms-1' }
    when :red
      { label: label, style: nil, class: 'bg-danger ms-1' }
    else
      nil
    end
  end
end


