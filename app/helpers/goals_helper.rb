module GoalsHelper
  include TerminologyHelper
  include AssociableGoalsHelper
  include MermaidFlowchartEscaping

  # Build Mermaid flowchart DSL for goal parent-child links.
  # Node IDs are safe (g_<id>); labels are escaped for Mermaid (quotes, backslashes).
  # Optional organization for click hrefs to goal show pages.
  def goals_mermaid_flowchart_dsl(goals, goal_links, organization: nil)
    return '' if goals.blank?

    lines = []
    lines << 'flowchart TB'
    lines << '%% Goal links: parent --> child'

    goal_ids = goals.map(&:id).to_set

    # Node definitions: g_<id>("Label")
    goals.each do |g|
      node_id = "g_#{g.id}"
      label = mermaid_normalize_flowchart_text(g.title).truncate(50)
      escaped_label = mermaid_escape_flowchart_label(label)
      lines << "  #{node_id}(\"#{escaped_label}\")"
    end

    # Edges: parent --> child
    goal_links.each do |link|
      pid = link.parent_id
      cid = link.child_id
      next unless goal_ids.include?(pid) && goal_ids.include?(cid)
      lines << "  g_#{pid} --> g_#{cid}"
    end

    lines.join("\n")
  end

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
      only_creator_owner_can_add_confidence_checks_label
    else
      no_permission_add_confidence_checks_label
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

  # Label for the goal's primary target date (for about_me last-confidence sentence).
  # Returns "most likely", "earliest", or "latest" depending on which date calculated_target_date used.
  def goal_primary_target_date_label(goal)
    return nil if goal.blank?
    calc = goal.calculated_target_date
    return nil if calc.blank?
    if goal.most_likely_target_date == calc
      'most likely'
    elsif goal.earliest_target_date == calc
      'earliest'
    elsif goal.latest_target_date == calc
      'latest'
    else
      'most likely'
    end
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
      confidence_check_mode_label
    else
      'View Mode' # Default
    end
  end
  
  def sort_goals_for_display(goals, sort: nil, direction: nil)
    Goals::CollectionSorter.call(
      goals,
      sort: sort || @goal_child_sort || @current_filters&.dig(:sort) || 'most_likely_target_date',
      direction: direction || @goal_child_sort_direction || @current_filters&.dig(:direction)
    )
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
            external_links = goal_external_association_links(organization, goal)
            content_tag(:span, goal.timeframe.to_s.humanize, class: "badge me-2 #{timeframe_badge_class(goal.timeframe)}", 'data-bs-toggle': 'tooltip', 'data-bs-title': timeframe_tooltip_text(goal)) +
            content_tag(:span, goal.status.to_s.humanize, class: "badge me-2 #{status_badge_class(goal.status)}") +
            content_tag(:span, goal_visibility_display(goal), class: 'text-muted small ms-2', 'data-bs-toggle': 'tooltip', 'data-bs-title': goal_privacy_tooltip_text(goal)) +
            owned_by_span + external_links
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

  # Goals index — "Add goals for …" uses teammate initials when owner param is CompanyTeammate_*.
  def goals_index_add_goals_button_initials_for(owner_param)
    m = owner_param.to_s.match(/\ACompanyTeammate_(\d+)\z/)
    return nil unless m

    teammate = CompanyTeammate.includes(:person).find_by(id: m[1])
    person = teammate&.person
    return nil unless person

    person.max_two_initials.presence || person.email.to_s.first.to_s.upcase || '?'
  end

  # Owner param for new/bulk goal links — use URL filter when present (even if teammate is not in switcher list).
  def goals_index_add_goal_owner_value(goal_special_owner_filter:, filter_owner_is_entity:, filter_owner_param:, selected_filter_is_owner:, selected_owner_value:, fallback_owner_value:)
    return fallback_owner_value if goal_special_owner_filter
    return filter_owner_param if filter_owner_is_entity
    return selected_owner_value if selected_filter_is_owner && selected_owner_value.present?

    fallback_owner_value
  end

  # Fallback text when initials are not shown (non-teammate owners).
  def goals_index_add_goal_owner_label(selected_owner_label:, filter_owner_param:, current_person:)
    if selected_owner_label.present?
      selected_owner_label.to_s.sub(/\A(?:Teammate|Company|Department|Team):\s*/, '')
    elsif (m = filter_owner_param.to_s.match(/\ACompanyTeammate_(\d+)\z/))
      teammate = CompanyTeammate.includes(:person).find_by(id: m[1])
      teammate&.person&.casual_name.presence || teammate&.person&.display_name.presence || 'myself'
    else
      current_person&.display_name.presence || 'myself'
    end
  end

  # Hierarchical-collapsible goals tree (see Goal#show_quick_note_cta_in_hierarchical_tree?).
  def show_hierarchical_collapsible_goal_quick_note_cta?(goal)
    goal.show_quick_note_cta_in_hierarchical_tree?(current_company_teammate)
  end

  # Returns a short phrase when the goal is associated to one or more prompts (e.g. "In reflection: Weekly Check-in"), or nil.
  def goal_prompt_association_display(goal)
    return nil if goal.prompt_goals.blank?

    titles = goal.prompt_goals.map { |pg| pg.prompt.prompt_template.title }.uniq
    return nil if titles.empty?

    reflection_label = company_label_for('reflection', 'Reflection')
    "In #{reflection_label.downcase}: #{titles.join(', ')}"
  end

  # Path to remove a PromptGoal or polymorphic GoalAssociation from the goal side or associable page.
  def goal_external_association_destroy_path(organization, association_record, return_url: nil, for_company_teammate_id: nil)
    case association_record
    when PromptGoal
      organization_prompt_prompt_goal_path(organization, association_record.prompt, association_record)
    when GoalAssociation
      extra = { return_url: return_url, for_company_teammate_id: for_company_teammate_id }.compact
      associable_goal_association_path(organization, association_record.associable, association_record, **extra)
    else
      raise ArgumentError, "Unsupported association record: #{association_record.class.name}"
    end
  end

  # Plain-text summary of non-prompt goal links (assignments, abilities, aspirations) for compact UI.
  def goal_non_prompt_associations_summary(goal)
    return nil if goal.goal_associations.blank?

    parts = []
    goal.goal_associations.includes(:associable).each do |ga|
      next unless ga.associable

      label = case ga.associable
              when Assignment
                "Assignment: #{ga.associable.title}"
              when Ability
                "Ability: #{ga.associable.name}"
              when Aspiration
                "Aspiration: #{ga.associable.name}"
              else
                ga.associable_type
              end
      parts << label
    end
    return nil if parts.empty?

    parts.uniq.join(' · ')
  end

  # Renders links for prompts + polymorphic associables next to goal title (index views).
  def goal_external_association_links(organization, goal)
    safe_join(
      goal_external_association_link_items(organization, goal).compact,
      tag.span(' ', class: 'text-muted')
    )
  end

  def goal_external_association_link_items(organization, goal)
    items = []
    if goal.association(:prompt_goals).loaded? ? goal.prompt_goals.any? : goal.prompt_goals.exists?
      pg = goal.prompt_goals.min_by(&:id)
      items << link_to(
        "| #{goal_prompt_association_display(goal)}",
        edit_organization_prompt_path(organization, pg.prompt),
        target: '_blank',
        rel: 'noopener',
        class: 'text-muted small text-decoration-none'
      )
    end

    associations = if goal.association(:goal_associations).loaded?
                     goal.goal_associations
                   else
                     goal.goal_associations.includes(:associable)
                   end

    associations.each do |ga|
      next unless ga.associable

      path = case ga.associable
             when Assignment
               organization_assignment_path(organization, ga.associable)
             when Ability
               organization_ability_path(organization, ga.associable)
             when Aspiration
               organization_aspiration_path(organization, ga.associable)
             else
               next
             end
      text = case ga.associable
             when Assignment
               "| Assignment: #{ga.associable.title}"
             when Ability
               "| Ability: #{ga.associable.name}"
             when Aspiration
               "| Aspiration: #{ga.associable.name}"
             end
      items << link_to(text, path, class: 'text-muted small text-decoration-none')
    end
    items
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
      teammate_profile_image(teammate, size: size)
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

  def goal_active?(goal)
    goal.started_at.present? && goal.completed_at.blank? && goal.deleted_at.blank?
  end

  # Most recent check-in for the completed-goal banner (reporter, outcome, learnings).
  def goal_completion_banner_check_in(goal)
    return nil unless goal_is_completed?(goal)

    goal.goal_check_ins.includes(:confidence_reporter).recent.first
  end

  def goal_completion_banner_emphasis(text)
    content_tag(:span, text, class: "goal-completion-banner__emphasis")
  end

  def goal_completion_banner_join_phrases(phrases)
    return nil if phrases.blank?

    case phrases.length
    when 1
      phrases.first
    when 2
      safe_join([phrases[0], " and ", phrases[1]])
    else
      safe_join([safe_join(phrases[0..-2], ", "), ", and ", phrases.last])
    end
  end

  def goal_completion_banner_target_dates_phrase(goal)
    clauses = []
    if goal.earliest_target_date.present?
      clauses << safe_join(["the earliest ", goal_completion_banner_emphasis(format_date_in_user_timezone(goal.earliest_target_date))])
    end
    if goal.latest_target_date.present?
      clauses << safe_join(["the latest ", goal_completion_banner_emphasis(format_date_in_user_timezone(goal.latest_target_date))])
    end
    if goal.most_likely_target_date.present?
      clauses << safe_join(["most likely on ", goal_completion_banner_emphasis(format_date_in_user_timezone(goal.most_likely_target_date))])
    end

    goal_completion_banner_join_phrases(clauses)
  end

  def goal_completion_banner_opening_paragraph(goal)
    start_at = goal.started_at || goal.created_at
    start_label = format_date_in_user_timezone(start_at)
    owner_name = goal_owner_display_name(goal)
    title = goal.title

    paragraph = safe_join([
      "On ",
      goal_completion_banner_emphasis(start_label),
      ", ",
      goal_completion_banner_emphasis(owner_name),
      " set out to ",
      goal_completion_banner_emphasis(title),
      "."
    ])

    target_dates = goal_completion_banner_target_dates_phrase(goal)
    if target_dates.present?
      paragraph = safe_join([paragraph, " They said they'd have this done by ", target_dates, "."])
    end

    if goal.initial_confidence.present?
      confidence_label = goal.initial_confidence.to_s.humanize
      paragraph = safe_join([
        paragraph,
        " This was a ",
        goal_completion_banner_emphasis(confidence_label),
        " confidence-level goal."
      ])
    end

    paragraph
  end

  def goal_completion_banner_reporter_casual_name(reporter)
    return "Someone" unless reporter

    reporter.casual_name.presence || reporter.display_name
  end

  def goal_completion_banner_outcome_label(check_in)
    case check_in&.confidence_percentage
    when 100
      "hit!"
    when 0
      "missed"
    else
      "#{check_in&.confidence_percentage}%"
    end
  end

  def goal_completion_banner_completion_paragraph(goal, check_in)
    completed_label = format_time_in_user_timezone(goal.completed_at)
    reporter_name = goal_completion_banner_reporter_casual_name(check_in&.confidence_reporter)
    outcome = goal_completion_banner_outcome_label(check_in)

    safe_join([
      "On ",
      goal_completion_banner_emphasis(completed_label),
      ", ",
      goal_completion_banner_emphasis(reporter_name),
      " marked this goal as ",
      goal_completion_banner_emphasis(outcome)
    ]) + "."
  end

  def goal_completion_banner_learnings_text(check_in)
    check_in&.confidence_reason.to_s.strip.presence
  end

  def goal_completion_banner_learnings_paragraph(check_in)
    learnings = goal_completion_banner_learnings_text(check_in)
    if learnings.present?
      safe_join([
        "Here is what they learned: ",
        content_tag(:span, learnings, class: "goal-completion-banner__emphasis goal-completion-banner__learnings")
      ])
    else
      content_tag(:span, "No learnings text was saved on the completion record.", class: "text-muted fst-italic")
    end
  end

  def goal_teammate_casual_name(teammate)
    return nil unless teammate&.person

    teammate.person.casual_name.presence || teammate.person.display_name
  end

  # Resolves last editor teammate for linking; uses PaperTrail meta (+current_teammate_id+) when present.
  def goal_last_updater_teammate(goal)
    v = goal_last_update_version(goal)
    teammate = goal_updater_teammate_from_version(v)
    return teammate if teammate

    if v.nil? && (goal.updated_at - goal.created_at).abs < 2.seconds
      goal.creator
    end
  end

  def goal_last_update_version(goal)
    PaperTrail::Version
      .where(item_type: 'Goal', item_id: goal.id)
      .where.not(event: 'create')
      .order(created_at: :desc)
      .first
  end

  def goal_updater_teammate_from_version(version)
    return nil if version.blank?

    if version.respond_to?(:current_teammate_id) && version.current_teammate_id.present?
      CompanyTeammate.find_by(id: version.current_teammate_id)
    elsif version.whodunnit.present?
      CompanyTeammate.find_by(id: version.whodunnit)
    end
  end

  # PaperTrail actor + timestamps for goal history footer.
  def goal_audit_created_meta(goal)
    first_version = goal.versions.reorder(created_at: :asc, id: :asc).first
    [paper_trail_whodunnit_casual_name(first_version), goal.created_at]
  end

  def goal_audit_last_updated_meta(goal)
    last_update = goal.versions.where(event: 'update').reorder(created_at: :desc, id: :desc).first
    if last_update
      [paper_trail_whodunnit_casual_name(last_update), last_update.created_at]
    else
      first_version = goal.versions.reorder(created_at: :asc, id: :asc).first
      [paper_trail_whodunnit_casual_name(first_version), goal.updated_at]
    end
  end

  def goal_creator_and_last_updated_phrase(goal, organization)
    creator = goal.creator
    creator_label = goal_teammate_casual_name(creator)
    creator_path = goal_teammate_path(organization, creator)
    created_part = format_time_in_user_timezone(goal.created_at)

    creator_html =
      if creator_path.present?
        link_to creator_label, creator_path, class: 'text-decoration-none'
      else
        creator_label
      end

    updater = goal_last_updater_teammate(goal)
    last_version = goal_last_update_version(goal)
    updated_part = format_time_in_user_timezone(goal.updated_at)

    if updater || last_version.present?
      updater_label = if last_version.present?
        paper_trail_whodunnit_casual_name(last_version)
      else
        goal_teammate_casual_name(updater)
      end
      updater_path = updater.present? ? goal_teammate_path(organization, updater) : nil
      impersonating = last_version.respond_to?(:impersonating_teammate_id) && last_version.impersonating_teammate_id.present?
      link_ok = updater_path.present? && (last_version.blank? || !impersonating)
      updater_html =
        if link_ok
          link_to updater_label, updater_path, class: 'text-decoration-none'
        else
          updater_label
        end
      safe_join(
        [
          creator_html,
          " created on #{created_part}, and ",
          updater_html,
          " last updated on #{updated_part}."
        ],
        ''
      )
    else
      safe_join(
        [
          creator_html,
          " created on #{created_part}, and last updated on #{updated_part}."
        ],
        ''
      )
    end
  end

  def goal_last_check_in_recency_phrase(goal)
    last = goal.goal_check_ins.recent.first
    return goal_has_no_confidence_checks_label if last.blank?

    last_confidence_check_ago_label(time: time_ago_in_words(last.created_at))
  end

  def goal_owner_path(organization, goal)
    owner = goal.owner
    return nil unless owner

    case owner
    when CompanyTeammate
      about_me_organization_company_teammate_path(organization, owner)
    when Department
      organization_department_path(organization, owner)
    when Team
      organization_team_path(organization, owner)
    when Organization
      organization_path(owner)
    end
  end

  def goal_teammate_path(organization, teammate)
    return nil unless teammate

    about_me_organization_company_teammate_path(organization, teammate)
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

  TOOLTIP_NESTED_BULK_GOALS_EXAMPLE = <<~TEXT.squish.freeze
    This is here to help you create clear goals the OG way—which means goals that are organized and nested.
    Completion of one thing makes everything else either easier or unnecessary, continuously pushing you toward your ultimate goals!
  TEXT

  def nested_bulk_goals_example_tooltip
    TOOLTIP_NESTED_BULK_GOALS_EXAMPLE
  end

  # Sample bulk paste for nested goal creation (Goals::ParseService). Used by manage/bulk goal forms.
  # Every line ends with the associated object name in parentheses so the pattern is obvious for sub-goals too.
  def nested_bulk_goals_example_text(associated_object_label = nil)
    label = associated_object_label.to_s.strip.presence || "this context"
    suf = " (#{label})"

    (1..3).map do |obj_num|
      kr_block = (1..3).map do |kr|
        activity_lines = (1..3).map { |a| "    #{a}. Activity #{a} under KR #{kr}#{suf}" }.join("\n")
        "* Key Result #{kr} for Objective #{obj_num}#{suf}\n#{activity_lines}"
      end.join("\n")

      "Objective #{obj_num}#{suf}\n#{kr_block}"
    end.join("\n\n")
  end
end

