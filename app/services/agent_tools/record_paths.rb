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

    def extract_id(path_or_url, resource:)
      path = path_or_url.to_s
      path = URI.parse(path).path if path.match?(%r{\Ahttps?://}i)
      match = path.match(%r{/#{Regexp.escape(resource)}/(\d+)(?:/|\z|\?)})
      match && match[1].to_i
    rescue URI::InvalidURIError
      nil
    end

    def helpers
      Rails.application.routes.url_helpers
    end
  end
end
