# frozen_string_literal: true

module AgentTools
  # Goals visible to the caller: policy_scope → FilterQuery → optional filters → can_be_viewed_by?.
  # Every row includes ownership/creator context; filters are optional and AND together.
  class ListGoals < Base
    DEFAULT_LIMIT = 25
    OWNER_TYPES = %w[CompanyTeammate Organization Department Team].freeze

    def call(
      context:,
      needing_check_in: false,
      owned_by_me: false,
      created_by_me: false,
      everyone_in_company: false,
      my_relevant_goals: false,
      owner_type: nil,
      owner_path: nil,
      owner_id: nil,
      limit: DEFAULT_LIMIT,
      **_ignored
    )
      context.authorize!(context.organization, :show?)

      teammate = context.company_teammate
      bool = ActiveModel::Type::Boolean.new

      needing = bool.cast(needing_check_in)
      filter_owned_by_me = bool.cast(owned_by_me)
      filter_created_by_me = bool.cast(created_by_me)
      filter_everyone = bool.cast(everyone_in_company)
      filter_relevant = bool.cast(my_relevant_goals)

      scoped = context.policy_scope(Goal)
      goals = Goals::FilterQuery.new(scoped).call(show_deleted: false, show_completed: false)
      goals = apply_relation_filters(
        goals,
        teammate: teammate,
        owned_by_me: filter_owned_by_me,
        created_by_me: filter_created_by_me,
        everyone_in_company: filter_everyone,
        my_relevant_goals: filter_relevant,
        owner_type: owner_type,
        owner_path: owner_path,
        owner_id: owner_id,
        context: context
      )

      visible = goals.includes(:creator, :owner).select { |goal| goal.can_be_viewed_by?(context.person) }

      if needing
        needing_ids = GoalsNeedingCheckInQuery.new(teammate: teammate).call.map(&:id).to_set
        visible = visible.select { |goal| needing_ids.include?(goal.id) }
      end

      limited = visible.first(limit.to_i.clamp(1, 50))

      ok(
        goals: limited.map { |g| serialize(context, g) },
        count: limited.size,
        filters: {
          needing_check_in: needing,
          owned_by_me: filter_owned_by_me,
          created_by_me: filter_created_by_me,
          everyone_in_company: filter_everyone,
          my_relevant_goals: filter_relevant,
          owner_type: normalize_owner_type(owner_type),
          owner_path: owner_path.presence,
          owner_id: owner_id.presence
        }
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    rescue ArgumentError => e
      err(e.message, code: "validation_failed")
    end

    private

    def apply_relation_filters(
      goals,
      teammate:,
      owned_by_me:,
      created_by_me:,
      everyone_in_company:,
      my_relevant_goals:,
      owner_type:,
      owner_path:,
      owner_id:,
      context:
    )
      if owned_by_me
        raise ArgumentError, "owned_by_me requires a company teammate" unless teammate

        goals = goals.where(owner_type: "CompanyTeammate", owner_id: teammate.id)
      end

      if created_by_me
        raise ArgumentError, "created_by_me requires a company teammate" unless teammate

        goals = goals.where(creator_id: teammate.id)
      end

      goals = goals.where(privacy_level: "everyone_in_company") if everyone_in_company

      if my_relevant_goals
        raise ArgumentError, "my_relevant_goals requires a company teammate" unless teammate

        goals = goals.active.merge(my_relevant_goals_condition(teammate))
      end

      specific_owner = resolve_specific_owner(
        context: context,
        owner_type: owner_type,
        owner_path: owner_path,
        owner_id: owner_id
      )
      if specific_owner
        goals = goals.where(owner_type: specific_owner[:type], owner_id: specific_owner[:id])
      end

      goals
    end

    def my_relevant_goals_condition(teammate)
      company_wide = Goal.where(privacy_level: "everyone_in_company")
      company_wide.or(Goal.where(owner_type: "CompanyTeammate", owner_id: teammate.id))
    end

    def resolve_specific_owner(context:, owner_type:, owner_path:, owner_id:)
      type = normalize_owner_type(owner_type)
      path = owner_path.to_s.strip.presence
      id = owner_id.presence

      return nil if type.blank? && path.blank? && id.blank?

      if path.present?
        resolved = RecordPaths.resolve_goal_owner(context, path: path, owner_type: type)
        raise ArgumentError, "Could not resolve owner_path" unless resolved

        return { type: resolved[:type], id: resolved[:id] }
      end

      raise ArgumentError, "owner_type is required when filtering by owner_id" if type.blank?
      raise ArgumentError, "owner_id or owner_path is required when filtering by owner_type" if id.blank?
      raise ArgumentError, "Unsupported owner_type: #{type}" unless OWNER_TYPES.include?(type)

      { type: type, id: id.to_i }
    end

    def normalize_owner_type(owner_type)
      type = owner_type.to_s.strip.presence
      return nil if type.blank?

      type = "Organization" if type == "Company"
      type
    end

    def serialize(context, goal)
      teammate = context.company_teammate
      owner = goal.owner
      creator = goal.creator

      owned_by_me =
        teammate.present? &&
        goal.owner_type == "CompanyTeammate" &&
        goal.owner_id == teammate.id
      created_by_me = teammate.present? && goal.creator_id == teammate.id

      {
        title: goal.title,
        path: RecordPaths.goal_path(context, goal),
        most_likely_target_date: goal.most_likely_target_date&.iso8601,
        privacy_level: goal.privacy_level,
        owned_by_me: owned_by_me,
        created_by_me: created_by_me,
        owner: serialize_owner(context, goal, owner),
        creator: serialize_creator(context, creator)
      }
    end

    def serialize_owner(context, goal, owner)
      return nil unless goal.owner_type.present? && owner

      {
        type: goal.owner_type,
        name: owner_display_name(goal, owner),
        path: RecordPaths.goal_owner_path(context, owner)
      }
    end

    def serialize_creator(context, creator)
      return nil unless creator

      {
        name: creator.person&.display_name,
        path: RecordPaths.teammate_path(context, creator)
      }
    end

    def owner_display_name(goal, owner)
      if goal.owner_type == "CompanyTeammate"
        owner.person&.display_name || "Unknown"
      else
        owner.try(:display_name).presence || owner.try(:name).presence || "Unknown"
      end
    end
  end
end
