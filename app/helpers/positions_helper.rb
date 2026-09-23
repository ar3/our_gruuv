module PositionsHelper
  def position_expectation_alignment_score_blurb(band, position)
    return "" if band.blank? || band[:blurb].blank?

    before, after = band[:blurb].split(/%\{position\}/, 2)
    safe_join([ before, tag.strong(position.display_name), after ].compact)
  end

  def positions_index_other_actions(organization)
    actions = [
      {
        label: "Position levels",
        path: organization_position_major_levels_path(organization),
        icon: "bi-layers"
      }
    ]

    if policy(organization).download_bulk_csv?
      actions.concat(
        [
          {
            label: "Download positions (CSV)",
            path: download_organization_bulk_downloads_path(organization, type: "positions"),
            icon: "bi-download"
          },
          {
            label: "Download titles (CSV)",
            path: download_organization_bulk_downloads_path(organization, type: "titles"),
            icon: "bi-download"
          }
        ]
      )
    end

    actions
  end

  # PaperTrail actor + timestamps for position Spotlight card (same pattern as titles / abilities).
  def position_audit_created_meta(position)
    first_version = position.versions.reorder(created_at: :asc, id: :asc).first
    [
      paper_trail_whodunnit_casual_name(first_version),
      position.created_at
    ]
  end

  def position_audit_last_updated_meta(position)
    last_update = position.versions.where(event: 'update').reorder(created_at: :desc, id: :desc).first
    if last_update
      [paper_trail_whodunnit_casual_name(last_update), last_update.created_at]
    else
      first_version = position.versions.reorder(created_at: :asc, id: :asc).first
      [paper_trail_whodunnit_casual_name(first_version), position.updated_at]
    end
  end

  # Same grouping as shared/forms/_position_field (seat management).
  # Optional suggested groups appear first (also remain in dept groups).
  # suggested_groups: [{ label:, positions: }, ...]
  def positions_grouped_options_for_select(positions_by_department, selected_id, suggested_positions: nil, suggested_groups: nil)
    groups = Array(suggested_groups)
    if groups.blank? && suggested_positions.present?
      groups = [{ label: "Suggested next", positions: Array(suggested_positions) }]
    end

    return '' if positions_by_department.blank? && groups.none? { |g| Array(g[:positions]).any? }

    grouped_options = []

    groups.each do |group|
      positions = Array(group[:positions])
      next if positions.blank?

      label = group[:label].presence || "Suggested next"
      grouped_options << [label, positions.map { |p| [p.display_name, p.id] }]
    end

    return grouped_options_for_select(grouped_options, selected_id) if positions_by_department.blank?

    organization = positions_by_department.keys.find { |org| org.is_a?(Organization) && !org.is_a?(Department) }
    departments = positions_by_department.keys.select { |org| org.is_a?(Department) }.sort_by(&:display_name)

    if organization && positions_by_department[organization].any?
      org_positions = positions_by_department[organization].map { |p| [p.display_name, p.id] }
      grouped_options << [organization.display_name, org_positions]
    end

    departments.each do |dept|
      next unless positions_by_department[dept].any?

      dept_positions = positions_by_department[dept].map { |p| [p.display_name, p.id] }
      grouped_options << [dept.display_name, dept_positions]
    end

    grouped_options_for_select(grouped_options, selected_id)
  end

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

  # Rows for Job Description "Required Abilities" section: each ability, description,
  # and each required milestone with markdown noting which Assignments require at least that level.
  # Uses the same union as MyGrowthAbilityMilestoneRows (direct + required assignments).
  def job_description_required_ability_rows(position)
    structured = MyGrowthAbilityMilestoneRows.structured_requirements_by_ability_id(position)
    return [] if structured.blank?

    abilities = Ability.where(id: structured.keys).index_by(&:id)
    structured.keys.filter_map do |ability_id|
      ability = abilities[ability_id]
      next unless ability

      sources = structured[ability_id][:sources]
      levels = sources.map { |source| source[:level].to_i }.uniq.sort
      {
        ability: ability,
        milestones: levels.map { |level| job_description_required_milestone_row(ability, level, sources) }
      }
    end.sort_by { |row| row[:ability].name.to_s.downcase }
  end

  def job_description_required_milestone_row(ability, level, sources)
    assignment_titles = sources
      .select { |source| source[:kind] == :assignment && source[:level].to_i >= level }
      .map { |source| source[:assignment]&.title.presence }
      .compact
      .uniq
    required_directly = sources.any? { |source| source[:kind] == :direct && source[:level].to_i >= level }
    description = ability.milestone_description(level).to_s
    markdown_parts = []
    markdown_parts << description if description.present?
    if assignment_titles.any?
      markdown_parts << "Assignments that require at least this milestone: #{assignment_titles.to_sentence}."
    end
    if required_directly
      markdown_parts << "Also required directly by the position."
    end

    {
      milestone_level: level,
      markdown: markdown_parts.join("\n\n")
    }
  end

  def job_description_hr_source_state_label(state)
    case state.to_sym
    when :using, :chosen then "using this"
    when :does_not_exist, :undefined then "does not exist"
    when :not_used, :skipped then "not used"
    when :na then "N/A"
    else state.to_s
    end
  end

  def job_description_hr_source_actions(node, organization:, title: nil, seat: nil, teammate: nil, public_view: false)
    return [] if public_view

    if node.key.to_sym == :seat
      actions = []
      if seat.present?
        actions << {
          label: "Click to Configure Seat",
          path: edit_organization_seat_path(organization, seat)
        }
      end
      if teammate.present?
        casual = teammate.person.casual_name.to_s.strip
        actions << {
          label: "Click to modify #{casual}'s seat",
          path: organization_teammate_position_path(organization, teammate)
        }
      end
      return actions
    end

    return [] if %i[na not_used skipped].include?(node.state.to_sym)

    path =
      case node.key.to_sym
      when :title
        edit_organization_title_path(organization, title) if title.present?
      when :organization
        edit_organization_company_preference_path(organization)
      end

    path.present? ? [{ label: "Click to Configure", path: path }] : []
  end

  def job_description_hr_source_edit_path(node, organization:, title: nil, seat: nil, teammate: nil, public_view: false)
    job_description_hr_source_actions(
      node,
      organization: organization,
      title: title,
      seat: seat,
      teammate: teammate,
      public_view: public_view
    ).first&.fetch(:path)
  end

  # Format a list of milestone levels for display, e.g. [1, 2, 3] => "1, 2, & 3"
  def milestone_levels_sentence(levels)
    return '' if levels.blank?
    levels = levels.map(&:to_i).sort.uniq
    return levels.first.to_s if levels.size == 1
    return levels.join(' & ') if levels.size == 2
    "#{levels[0..-2].join(', ')}, & #{levels.last}"
  end

  def current_view_name
    if controller_path == 'organizations/positions/maap_clarity'
      return 'Consult OG'
    end

    case action_name
    when 'show'
      'Management View'
    when 'job_description'
      'Job Description View'
    when 'manage_assignments'
      'Manage Assignments'
    else
      'Management View'
    end
  end

  def energy_percentage_options(selected_value = nil)
    options = (0..20).map { |i| ["#{i * 5}%", i * 5] }
    # If a selected_value is provided, return pre-selected HTML options
    # Otherwise, return the array for use with form helpers
    selected_value.nil? ? options : options_for_select(options, selected_value)
  end

  def build_assignment_hierarchy_tree(assignments_by_org, company)
    return [] unless company&.company?
    
    result = []
    
    # Get assignments without department (company-level)
    company_assignments = assignments_by_org[nil] || []
    
    # Add company-level assignments if any
    if company_assignments.any?
      result << {
        organization: company,
        assignments: company_assignments,
        level: 0,
        children: []
      }
    end
    
    # Recursively build department structure (root departments only at top level)
    company.departments.active.where(parent_department_id: nil).order(:name).each do |department|
      department_assignments = assignments_by_org[department] || []
      
      # Recursively get children departments with assignments
      child_nodes = build_department_children(assignments_by_org, department)
      
      # Only include department if it has assignments or children with assignments
      if department_assignments.any? || child_nodes.any?
        result << {
          organization: department,
          assignments: department_assignments,
          level: department.ancestry_depth,
          children: child_nodes
        }
      end
    end
    
    result
  end

  def department_hierarchy_display(department)
    return '' unless department
    return department.display_name if department.is_a?(Department)
    
    # Fallback for Organization (legacy support)
    return department.name unless department&.respond_to?(:parent_department) && department.parent_department
    
    path = []
    current = department
    while current
      path.unshift(current.name)
      current = current.respond_to?(:parent_department) ? current.parent_department : nil
    end
    path.join(' > ')
  end

  # Returns a comparison URL when both positions exist and the viewer can open Position Comparison.
  def organization_position_comparison_url_for(organization, left_position:, right_position:)
    return nil if left_position.blank? || right_position.blank?
    return nil unless policy(:eligibility_requirement).index?

    organization_position_comparison_path(
      organization,
      left_position_id: left_position.id,
      right_position_id: right_position.id
    )
  end

  private

  def build_department_children(assignments_by_org, department)
    result = []
    
    department.child_departments.active.order(:name).each do |child_dept|
      child_assignments = assignments_by_org[child_dept] || []
      grandchild_nodes = build_department_children(assignments_by_org, child_dept)
      
      if child_assignments.any? || grandchild_nodes.any?
        result << {
          organization: child_dept,
          assignments: child_assignments,
          level: child_dept.ancestry_depth,
          children: grandchild_nodes
        }
      end
    end
    
    result
  end
end
