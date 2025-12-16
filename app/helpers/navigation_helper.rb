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
        label: 'My Check-In',
        icon: 'bi-clipboard-check',
        path: organization_company_teammate_check_ins_path(current_organization, current_company_teammate),
        section: nil,
        policy_check: -> { policy(current_company_teammate).view_check_ins? }
      },
      {
        label: 'Observations',
        icon: 'bi-eye',
        path: organization_observations_path(current_organization),
        section: nil,
        policy_check: -> { policy(Observation).index? }
      },
      {
        label: 'Reflect',
        icon: 'bi-journal-text',
        path: organization_prompts_path(current_organization),
        section: nil,
        policy_check: -> { policy(Prompt).index? }
      },
      {
        label: 'Goals',
        icon: 'bi-bullseye',
        path: organization_goals_path(current_organization),
        section: nil,
        policy_check: -> { policy(Goal).index? }
      },
      {
        label: 'My Teammates',
        icon: 'bi-people',
        path: organization_employees_path(current_organization),
        section: nil,
        policy_check: -> { policy(Organization).show? }
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
end

