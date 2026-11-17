# frozen_string_literal: true

module AgentTools
  # Shared helpers for MCP / AgentTools goal create, start, update, and confidence.
  module GoalMutations
    module_function

    def company_for(context)
      org = context.organization
      org.respond_to?(:root_company) && org.root_company.present? ? org.root_company : org
    end

    def owner_value_for(owner_type:, owner_id:)
      type = owner_type.to_s
      type = "Company" if type == "Organization"
      "#{type}_#{owner_id}"
    end

    def privacy_for_owner_type(owner_type)
      case owner_type.to_s
      when "Team", "Department", "Company", "Organization"
        "everyone_in_company"
      else
        "only_creator_owner_and_managers"
      end
    end

    def resolve_owner!(context, owner_path:, owner_type: nil, owner_id: nil)
      path = owner_path.to_s.strip.presence
      type = owner_type.to_s.strip.presence
      type = "Organization" if type == "Company"
      id = owner_id.presence

      if path.present?
        resolved = RecordPaths.resolve_goal_owner(context, path: path, owner_type: type)
        raise ArgumentError, "Could not resolve owner_path" unless resolved

        return resolved
      end

      raise ArgumentError, "owner_path or owner_type+owner_id is required" if type.blank? || id.blank?

      normalized = type == "Company" ? "Organization" : type
      unless %w[CompanyTeammate Organization Department Team].include?(normalized)
        raise ArgumentError, "Unsupported owner_type: #{type}"
      end

      { type: normalized, id: id.to_i }
    end

    def find_visible_goal!(context, goal_path:, goal_id: nil)
      raise ArgumentError, "goal_path is required" if goal_path.blank? && goal_id.blank?

      goal = RecordPaths.resolve_goal(context, goal_path: goal_path, goal_id: goal_id)
      raise ArgumentError, "goal not found" if goal.nil?
      raise ArgumentError, "goal not in organization" unless goal.company_id == company_for(context).id
      raise AgentTools::NotAuthorized, "goal not viewable" unless goal.can_be_viewed_by?(context.person)

      goal
    end

    def resolve_parent_goals!(context, parent_goal_paths:)
      Array(parent_goal_paths).filter_map do |path|
        next if path.blank?

        parent = RecordPaths.resolve_goal(context, goal_path: path)
        raise ArgumentError, "parent goal not found: #{path}" if parent.nil?
        raise ArgumentError, "parent goal not in organization" unless parent.company_id == company_for(context).id
        raise AgentTools::NotAuthorized, "parent goal not viewable" unless parent.can_be_viewed_by?(context.person)

        parent
      end
    end

    def serialize_goal(context, goal)
      {
        title: goal.title,
        path: RecordPaths.goal_path(context, goal),
        status: goal.status.to_s,
        goal_type: goal.goal_type,
        description: goal.description,
        most_likely_target_date: goal.most_likely_target_date&.iso8601,
        earliest_target_date: goal.earliest_target_date&.iso8601,
        latest_target_date: goal.latest_target_date&.iso8601,
        privacy_level: goal.privacy_level,
        initial_confidence: goal.initial_confidence,
        owner: {
          type: goal.owner_type,
          path: RecordPaths.goal_owner_path(context, goal.owner),
          name: owner_display_name(goal)
        },
        parent_paths: goal.linking_goals.map { |p| RecordPaths.goal_path(context, p) }
      }
    end

    def owner_display_name(goal)
      owner = goal.owner
      return "Unknown" unless owner

      if goal.owner_type == "CompanyTeammate"
        owner.person&.display_name || "Unknown"
      else
        owner.try(:display_name).presence || owner.try(:name).presence || "Unknown"
      end
    end

    def link_parents!(context:, child:, parents:)
      Array(parents).each do |parent|
        next if GoalLink.exists?(parent_id: parent.id, child_id: child.id)

        link = GoalLink.new(parent_id: parent.id, child_id: child.id)
        context.authorize!(link, :create?)
        raise ActiveRecord::RecordInvalid, link unless link.save
      end
    end

    def unlink_parents!(context:, child:, parents:)
      Array(parents).each do |parent|
        link = GoalLink.find_by(parent_id: parent.id, child_id: child.id)
        next unless link

        context.authorize!(link, :destroy?)
        link.destroy!
      end
    end
  end
end
