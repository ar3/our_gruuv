# frozen_string_literal: true

module AgentTools
  # Builds org-relative paths for tool context and resolves them back to records.
  # Prefer paths over numeric ids in LLM-facing payloads.
  module RecordPaths
    module_function

    def organization_path_for(context, *args, **kwargs)
      helpers.organization_path(context.organization, *args, **kwargs)
    end

    def teammate_path(context, teammate)
      helpers.internal_organization_company_teammate_path(context.organization, teammate)
    end

    def goal_path(context, goal)
      helpers.organization_goal_path(context.organization, goal)
    end

    def observation_path(context, observation)
      helpers.organization_observation_path(context.organization, observation)
    end

    def assignment_path(context, assignment)
      helpers.organization_assignment_path(context.organization, assignment)
    end

    def ability_path(context, ability)
      helpers.organization_ability_path(context.organization, ability)
    end

    def title_path(context, title)
      helpers.organization_title_path(context.organization, title)
    end

    def position_path(context, position)
      helpers.organization_position_path(context.organization, position)
    end

    def department_path(context, department)
      helpers.organization_department_path(context.organization, department)
    end

    def aspiration_path(context, aspiration)
      helpers.organization_aspiration_path(context.organization, aspiration)
    end

    def resolve_position(context, path: nil, position_path: nil, position_id: nil)
      path = path.presence || position_path.presence
      if path.present?
        id = extract_id(path, resource: "positions")
        return Position.find_by(id: id) if id
      end
      return Position.find_by(id: position_id) if position_id.present?

      nil
    end

    def resolve_title(context, path: nil, title_path: nil, title_id: nil)
      path = path.presence || title_path.presence
      if path.present?
        id = extract_id(path, resource: "titles")
        return Title.find_by(id: id) if id
      end
      return Title.find_by(id: title_id) if title_id.present?

      nil
    end

    def resolve_department(context, path: nil, department_path: nil, department_id: nil)
      path = path.presence || department_path.presence
      if path.present?
        id = extract_id(path, resource: "departments")
        return Department.find_by(id: id) if id
      end
      return Department.find_by(id: department_id) if department_id.present?

      nil
    end

    def resolve_teammate(context, path: nil, observee_path: nil, observee_teammate_id: nil)
      path = path.presence || observee_path.presence
      if path.present?
        id = extract_id(path, resource: "company_teammates") || extract_id(path, resource: "teammates")
        return CompanyTeammate.find_by(id: id) if id
      end
      return CompanyTeammate.find_by(id: observee_teammate_id) if observee_teammate_id.present?

      nil
    end

    def resolve_goal(context, path: nil, goal_path: nil, goal_id: nil)
      path = path.presence || goal_path.presence
      if path.present?
        id = extract_id(path, resource: "goals")
        return Goal.find_by(id: id) if id
      end
      return Goal.find_by(id: goal_id) if goal_id.present?

      nil
    end

    def goal_owner_path(context, owner)
      case owner
      when CompanyTeammate
        teammate_path(context, owner)
      when Department
        helpers.organization_department_path(context.organization, owner)
      when Team
        helpers.organization_team_path(context.organization, owner)
      when Organization
        helpers.organization_path(owner)
      end
    rescue StandardError
      nil
    end

    # Returns { type:, id: } for goal owner filter args, or nil if unresolved.
    def resolve_goal_owner(context, path: nil, owner_type: nil)
      path = path.to_s.strip.presence
      return nil if path.blank?

      type = owner_type.to_s.strip.presence
      type = "Organization" if type == "Company"

      if type.blank? || type == "CompanyTeammate"
        teammate = resolve_teammate(context, path: path)
        return { type: "CompanyTeammate", id: teammate.id } if teammate
      end

      if type.blank? || type == "Department"
        id = extract_id(path, resource: "departments")
        return { type: "Department", id: id } if id
      end

      if type.blank? || type == "Team"
        id = extract_id(path, resource: "teams")
        return { type: "Team", id: id } if id
      end

      if type.blank? || type == "Organization"
        id = extract_id(path, resource: "organizations")
        return { type: "Organization", id: id } if id
      end

      nil
    end

    def extract_id(path_or_url, resource:)
      path = path_or_url.to_s
      path = URI.parse(path).path if path.match?(%r{\Ahttps?://}i)
      # Supports numeric ids and friendly to_param slugs ("12-software-engineer").
      match = path.match(%r{/#{Regexp.escape(resource)}/(\d+)(?:-|/|\z|\?)})
      match && match[1].to_i
    rescue URI::InvalidURIError
      nil
    end

    def helpers
      Rails.application.routes.url_helpers
    end
  end
end
