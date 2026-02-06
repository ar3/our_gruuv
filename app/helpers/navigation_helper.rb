module NavigationHelper
  # Get the root company for the current organization
  def current_company
    @current_company ||= current_organization&.root_company || current_organization
  end
  
  # Calculate pending items count for Get Shit Done dashboard
  # Uses the same query service as the controller to ensure consistency
  def pending_get_shit_done_count(teammate)
    return 0 unless teammate
    
    GetShitDoneQueryService.new(teammate: teammate).total_pending_count
  end

  # Navigation structure definition
  def navigation_structure
    return [] unless current_organization && current_person
    
    [
      {
        label: "About #{current_company_teammate&.person&.casual_name || 'Me'}",
        icon: 'bi-person',
        path: about_me_organization_company_teammate_path(current_organization, current_company_teammate),
        section: nil,
        policy_check: -> { current_company_teammate && policy(current_company_teammate).view_check_ins? }
      },
      {
        label: 'My Check-In',
        icon: 'bi-clipboard-check',
        path: organization_company_teammate_check_ins_path(current_organization, current_company_teammate),
        section: nil,
        policy_check: -> { policy(current_company_teammate).view_check_ins? }
      },
      {
        label: 'Observations (OGO)',
        icon: 'bi-eye',
        section: 'observations_ogo',
        items: [
          {
            label: 'Add New OGO',
            icon: 'bi-plus-circle',
            path: select_type_organization_observations_path(current_organization),
            policy_check: -> { policy(current_company).view_observations? },
            coming_soon: false
          },
          {
            label: "#{current_organization&.name || 'Organization'} Highlights",
            icon: 'bi-gift',
            path: organization_observations_path(
              current_organization,
              privacy: %w[public_to_company public_to_world],
              spotlight: 'most_observed',
              view: 'wall'
            ),
            policy_check: -> { policy(current_company).view_observations? },
            coming_soon: false
          },
          {
            label: "OGO's involving me",
            icon: 'bi-person',
            path: organization_observations_path(current_organization, involving_teammate_id: current_company_teammate&.id),
            policy_check: -> { current_company_teammate.present? && policy(current_company).view_observations? },
            coming_soon: false
          },
          {
            label: 'All observations',
            icon: 'bi-list-ul',
            path: organization_observations_path(current_organization),
            policy_check: -> { policy(current_company).view_observations? },
            coming_soon: false
          }
        ]
      },
      {
        label: 'Teammate Directory',
        icon: 'bi-people',
        section: 'directory',
        items: [
          {
            label: 'View Teammates',
            icon: 'bi-people',
            path: organization_employees_path(current_organization, spotlight: 'teammate_tenures'),
            policy_check: -> { policy(Organization).show? },
            coming_soon: false
          },
          {
            label: 'My Employees',
            icon: 'bi-person-badge',
            path: organization_employees_path(current_organization, manager_teammate_id: current_company_teammate&.id, view: 'managers_view', spotlight: 'manager_lite'),
            policy_check: -> { current_company_teammate&.has_direct_reports? && policy(Organization).show? },
            coming_soon: false
          },
          {
            label: 'Employee Hierarchy',
            icon: 'bi-diagram-3',
            path: organization_employees_path(
              current_organization,
              spotlight: 'manager_distribution',
              status: %w[unassigned_employee assigned_employee],
              view: 'vertical_hierarchy'
            ),
            policy_check: -> { policy(Organization).show? },
            coming_soon: false
          }
        ]
      },
      {
        label: company_label_plural('prompt', 'Prompts'),
        icon: 'bi-journal-text',
        path: organization_prompts_path(current_organization),
        section: nil,
        policy_check: -> { policy(current_company).view_prompts? }
      },
      {
        label: 'Goals',
        icon: 'bi-bullseye',
        path: organization_goals_path(current_organization),
        section: nil,
        policy_check: -> { policy(current_company).view_goals? }
      },
      {
        label: 'Celebrate Milestones',
        icon: 'bi-trophy',
        path: celebrate_milestones_organization_path(current_organization),
        section: nil,
        policy_check: -> { policy(current_organization).show? }
      },
      {
        label: 'Huddles',
        icon: 'bi-chat-dots',
        section: 'huddles',
        items: [
          {
            label: 'Huddle Review',
            icon: 'bi-graph-up',
            path: huddles_review_organization_path(current_organization),
            policy_check: -> { policy(current_organization).show? },
            coming_soon: false
          },
          {
            label: 'My Huddles',
            icon: 'bi-person',
            path: my_huddles_path,
            policy_check: -> { policy(Huddle).show? },
            coming_soon: false
          },
          {
            label: "Today's Huddles",
            icon: 'bi-calendar-event',
            path: huddles_path,
            policy_check: -> { policy(Huddle).show? },
            coming_soon: false
          }
        ]
      },
      {
        label: 'Insights',
        icon: 'bi-bar-chart-line',
        section: 'insights',
        items: [
          {
            label: 'Observations',
            icon: 'bi-eye',
            path: organization_insights_observations_path(current_organization),
            policy_check: -> { policy(current_company).view_observations? },
            coming_soon: false
          },
          {
            label: 'Seats, Titles, Positions',
            icon: 'bi-briefcase',
            path: organization_insights_seats_titles_positions_path(current_organization),
            policy_check: -> { policy(current_company).view_seats? },
            coming_soon: false
          },
          {
            label: 'Assignments',
            icon: 'bi-list-check',
            path: organization_insights_assignments_path(current_organization),
            policy_check: -> { policy(current_company).view_assignments? },
            coming_soon: false
          },
          {
            label: 'Abilities',
            icon: 'bi-award',
            path: organization_insights_abilities_path(current_organization),
            policy_check: -> { policy(current_company).view_abilities? },
            coming_soon: false
          },
          {
            label: 'Goals',
            icon: 'bi-bullseye',
            path: organization_insights_goals_path(current_organization),
            policy_check: -> { policy(current_company).view_goals? },
            coming_soon: false
          },
          {
            label: 'Huddles',
            icon: 'bi-chat-dots',
            path: huddles_review_organization_path(current_organization),
            policy_check: -> { policy(current_organization).show? },
            coming_soon: false
          }
        ]
      },
      {
        label: 'Admin',
        icon: 'bi-gear',
        section: 'admin',
        items: [
          {
            label: 'Bank Awards',
            icon: 'bi-bank',
            path: organization_highlights_rewards_bank_awards_path(current_organization),
            policy_check: -> { policy(:highlights).award_bank_points? },
            coming_soon: false
          },
          {
            label: 'Rewards',
            icon: 'bi-gift',
            path: organization_highlights_rewards_rewards_path(current_organization),
            policy_check: -> { policy(:highlights).view_rewards_catalog? },
            coming_soon: false
          },
          {
            label: 'Eligibility Requirements 🚧 Beta',
            icon: 'bi-check2-circle',
            path: organization_eligibility_requirements_path(current_organization),
            policy_check: -> { policy(:eligibility_requirement).index? },
            coming_soon: false
          },
          {
            label: 'Feedback Requests 🚧 Beta',
            icon: 'bi-chat-dots',
            path: organization_feedback_requests_path(current_organization),
            policy_check: -> { policy(current_company).view_feedback_requests? },
            coming_soon: false
          },
          {
            label: 'Seats',
            icon: 'bi-briefcase',
            path: organization_seats_path(current_organization),
            policy_check: -> { policy(current_company).view_seats? },
            coming_soon: false
          },
          {
            label: 'Positions',
            icon: 'bi-briefcase-fill',
            path: organization_positions_path(current_organization),
            policy_check: -> { current_organization.present? && policy(current_organization).show? },
            coming_soon: false
          },
          {
            label: 'Assignments',
            icon: 'bi-list-check',
            path: organization_assignments_path(current_organization),
            policy_check: -> { policy(current_company).view_assignments? },
            coming_soon: false
          },
          {
            label: 'Abilities',
            icon: 'bi-award',
            path: organization_abilities_path(current_organization),
            policy_check: -> { policy(current_company).view_abilities? },
            coming_soon: false
          },
          {
            label: 'Aspirational Values',
            icon: 'bi-star',
            path: organization_aspirations_path(current_organization),
            policy_check: -> { policy(current_company).view_aspirations? },
            coming_soon: false
          },
          {
            label: 'Prompt Templates',
            icon: 'bi-file-text',
            path: organization_prompt_templates_path(current_organization),
            policy_check: -> { policy(current_company).view_prompt_templates? },
            coming_soon: false
          },
          {
            label: 'Departments',
            icon: 'bi-diagram-3',
            path: organization_departments_path(current_organization),
            policy_check: -> { policy(current_organization).show? },
            coming_soon: false
          },
          {
            label: 'Teams',
            icon: 'bi-people',
            path: organization_teams_path(current_organization),
            policy_check: -> { policy(current_organization).show? },
            coming_soon: false
          },
          {
            label: 'Bulk Events',
            icon: 'bi-upload',
            path: organization_bulk_sync_events_path(current_organization),
            policy_check: -> { policy(current_company).view_bulk_sync_events? },
            coming_soon: false
          },
          {
            label: 'Bulk Downloads',
            icon: 'bi-download',
            path: organization_bulk_downloads_path(current_organization),
            policy_check: -> { policy(current_company).view_bulk_sync_events? },
            coming_soon: false
          },
          {
            label: 'Slack Settings',
            icon: 'bi-slack',
            path: organization_slack_path(current_organization),
            policy_check: -> { policy(current_organization).manage_employment? },
            coming_soon: false
          },
          {
            label: 'Check-ins Health',
            icon: 'bi-heart-pulse',
            path: organization_check_ins_health_path(current_organization),
            policy_check: -> { policy(current_organization).manage_employment? },
            coming_soon: false
          },
          {
            label: "#{current_company.name} Preferences",
            icon: 'bi-sliders',
            path: edit_organization_company_preference_path(current_organization),
            policy_check: -> { policy(current_company).customize_company? },
            coming_soon: false
          }
        ]
      },
      {
        label: 'Help Improve OG',
        icon: 'bi-lightbulb',
        path: begin
          about_me_path = about_me_organization_company_teammate_path(current_organization, current_company_teammate)
          company_name = current_company&.name || current_organization&.name || 'OurGruuv'
          interest_submissions_path(return_url: about_me_path, return_text: "back to #{company_name}'s Gruuv")
        end,
        section: nil
      }
    ]
  end
  
  # Check if a navigation item is active.
  # - Link without query params: active when path matches (or path prefix), regardless of current request query.
  # - Link with query params: active only when path matches and current request query params equal the link's.
  def nav_item_active?(path)
    return false unless path

    path_str = path.to_s
    path_only = path_str.split('?').first
    link_query = path_str.include?('?') ? path_str.split('?', 2).last : nil

    path_match = request.path == path_only || request.path.start_with?("#{path_only}/")

    if link_query.blank?
      path_match
    else
      path_match && nav_query_params_match?(link_query, request)
    end
  end
  
  # Check if a section has any active items
  def section_has_active_item?(section_items)
    return false unless section_items
    section_items.any? { |item| nav_item_active?(item[:path]) }
  end
  
  # Filter navigation items by permissions
  def visible_nav_items(section_items)
    return [] unless section_items
    
    section_items.select do |item|
      next false if item[:policy_check].nil?
      
      begin
        item[:policy_check].call
      rescue => e
        Rails.logger.error "Navigation policy check failed: #{e.message}"
        false
      end
    end
  end
  
  # Get visible navigation structure (filtered by permissions)
  def visible_navigation_structure
    structure = navigation_structure
    
    structure.map do |section|
      if section[:items]
        visible_items = visible_nav_items(section[:items])
        # Only include section if it has visible items or is Dashboard
        if section[:label] == 'Dashboard' || visible_items.any?
          section.merge(items: visible_items)
        else
          nil
        end
      else
        # Standalone items (section: nil) - check policy if present
        if section[:policy_check]
          begin
            if section[:policy_check].call
              section
            else
              nil
            end
          rescue => e
            Rails.logger.error "Navigation policy check failed: #{e.message}"
            nil
          end
        else
          section
        end
      end
    end.compact
  end

  private

  def nav_query_params_match?(link_query, request)
    # Use parse_nested_query so array params (e.g. privacy[]=a&privacy[]=b) match request.query_parameters
    link_params = Rack::Utils.parse_nested_query(link_query)
    request_params = request.query_parameters
    link_params == request_params
  end
end

