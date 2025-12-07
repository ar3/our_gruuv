module NavigationHelper
  # Navigation structure definition
  def navigation_structure
    return [] unless current_organization && current_person
    
    [
      {
        label: 'Dashboard',
        icon: 'bi-house',
        path: dashboard_organization_path(current_organization),
        section: nil
      },
      {
        label: 'Align',
        icon: 'bi-compass',
        section: 'align',
        items: [
          {
            label: 'Observations',
            icon: 'bi-eye',
            path: organization_observations_path(current_organization),
            policy_check: -> { policy(Observation).index? },
            coming_soon: false
          },
          {
            label: 'Milestones',
            icon: 'bi-award',
            path: organization_abilities_path(current_organization),
            policy_check: -> { policy(Ability).index? },
            coming_soon: false
          },
          {
            label: 'Accountability',
            icon: 'bi-clipboard-check',
            path: accountability_path,
            policy_check: -> { current_organization.present? },
            coming_soon: false
          },
          {
            label: 'Positions',
            icon: 'bi-briefcase',
            path: organization_positions_path(current_organization),
            policy_check: -> { policy(Position).index? },
            coming_soon: false
          }
        ]
      },
      {
        label: 'Collab',
        icon: 'bi-people',
        section: 'collab',
        items: [
          {
            label: 'Huddles',
            icon: 'bi-chat-dots',
            path: huddles_path,
            policy_check: -> { policy(Huddle).index? },
            coming_soon: false
          },
          {
            label: 'Oppties',
            icon: 'bi-lightbulb',
            path: good_issues_coming_soon_path,
            policy_check: -> { true },
            coming_soon: true
          },
          {
            label: 'Diverge/Converge',
            icon: 'bi-arrows-collapse',
            path: diverge_converge_coming_soon_path,
            policy_check: -> { true },
            coming_soon: true
          }
        ]
      },
      {
        label: 'Transform',
        icon: 'bi-graph-up',
        section: 'transform',
        items: [
          {
            label: 'Goals',
            icon: 'bi-bullseye',
            path: organization_goals_path(current_organization),
            policy_check: -> { policy(Goal).index? },
            coming_soon: false
          },
          {
            label: 'Hypotheses',
            icon: 'bi-flask',
            path: hypothesis_management_coming_soon_path,
            policy_check: -> { true },
            coming_soon: true
          },
          {
            label: 'Signals',
            icon: 'bi-activity',
            path: team_signals_coming_soon_path,
            policy_check: -> { true },
            coming_soon: true
          }
        ]
      },
      {
        label: 'Admin',
        icon: 'bi-gear',
        section: 'admin',
        items: [
          {
            label: 'Seats',
            icon: 'bi-briefcase',
            path: organization_seats_path(current_organization),
            policy_check: -> { policy(Seat).index? },
            coming_soon: false
          },
          {
            label: 'Position Types',
            icon: 'bi-tag',
            path: position_types_path,
            policy_check: -> { current_organization.present? && policy(current_organization).show? },
            coming_soon: false
          },
          {
            label: 'Assignments',
            icon: 'bi-list-check',
            path: organization_assignments_path(current_organization),
            policy_check: -> { policy(Assignment).index? },
            coming_soon: false
          },
          {
            label: 'Abilities',
            icon: 'bi-award',
            path: organization_abilities_path(current_organization),
            policy_check: -> { policy(Ability).index? },
            coming_soon: false
          },
          {
            label: 'Aspirations',
            icon: 'bi-star',
            path: organization_aspirations_path(current_organization),
            policy_check: -> { policy(Aspiration).index? },
            coming_soon: false
          },
          {
            label: 'Employees',
            icon: 'bi-people',
            path: organization_employees_path(current_organization),
            policy_check: -> { policy(Organization).show? },
            coming_soon: false
          },
          {
            label: 'Organization',
            icon: 'bi-building',
            path: organization_path(current_organization),
            policy_check: -> { policy(current_organization).show? },
            coming_soon: false
          },
          {
            label: 'Check-ins Health',
            icon: 'bi-heart-pulse',
            path: organization_check_ins_health_path(current_organization),
            policy_check: -> { policy(current_organization).manage_employment? },
            coming_soon: false
          }
        ]
      }
    ]
  end
  
  # Check if a navigation item is active
  def nav_item_active?(path)
    return false unless path
    current_page?(path) || request.path.start_with?(path.to_s.split('?').first)
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
        section
      end
    end.compact
  end
end

