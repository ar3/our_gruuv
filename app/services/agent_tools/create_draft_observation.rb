# frozen_string_literal: true

module AgentTools
  # Creates a draft Observation only (published_at: nil). No publish / update / destroy.
  class CreateDraftObservation < Base
    include Rails.application.routes.url_helpers

    DEFAULT_TRIGGER_SOURCE = "ask_og"
    DEFAULT_TRIGGER_TYPE = "ask_og_assistant"
    DEFAULT_CREATED_AS = "ask_og"
    ALLOWED_TRIGGER_SOURCES = %w[ask_og mcp].freeze
    ALLOWED_TYPES = %w[kudos feedback quick_note].freeze

    def call(
      context:,
      observee_path: nil,
      observee_teammate_id: nil,
      story: nil,
      observation_type: "feedback",
      privacy_level: "observed_and_managers",
      goal_path: nil,
      goal_id: nil,
      trigger_source: DEFAULT_TRIGGER_SOURCE,
      trigger_type: nil,
      created_as_type: nil,
      **_ignored
    )
      context.authorize!(Observation.new(company: company_for(context)), :create?)

      source = trigger_source.to_s.presence || DEFAULT_TRIGGER_SOURCE
      unless ALLOWED_TRIGGER_SOURCES.include?(source)
        return err("invalid trigger_source", code: "validation_failed")
      end

      type = trigger_type.to_s.presence || (source == "mcp" ? "mcp_assistant" : DEFAULT_TRIGGER_TYPE)
      created_as = created_as_type.to_s.presence || (source == "mcp" ? "mcp" : DEFAULT_CREATED_AS)

      observee = RecordPaths.resolve_teammate(
        context,
        observee_path: observee_path,
        observee_teammate_id: observee_teammate_id
      )
      if observee_path.blank? && observee_teammate_id.blank?
        return err("observee path is required", code: "validation_failed")
      end
      return err("observee teammate not found", code: "not_found") if observee.nil?
      unless teammate_in_company_tree?(observee, company_for(context))
        return err("observee not in organization", code: "validation_failed")
      end

      kind = ALLOWED_TYPES.include?(observation_type.to_s) ? observation_type.to_s : "feedback"
      company = company_for(context)
      linked_goal = resolve_optional_goal(context, goal_path: goal_path, goal_id: goal_id)

      observation = nil
      ActiveRecord::Base.transaction do
        trigger = ObservationTrigger.create!(
          trigger_source: source,
          trigger_type: type,
          trigger_data: {
            "created_via" => source,
            "organization_id" => context.organization.id
          }
        )

        observation = company.observations.build(
          observer: context.person,
          creator_company_teammate: context.company_teammate,
          story: story.to_s.presence,
          privacy_level: privacy_level.presence || "observed_and_managers",
          observed_at: Time.current,
          published_at: nil,
          observation_type: kind,
          created_as_type: created_as,
          observation_trigger: trigger,
          goal_id: linked_goal&.id
        )
        raise ActiveRecord::RecordInvalid, observation unless observation.save

        Observations::AddObserveeService.new(observation: observation, teammate_id: observee.id).call
      end

      ok(
        path: edit_organization_observation_path(context.organization, observation),
        draft: true,
        published_at: observation.published_at,
        redirect_path: edit_organization_observation_path(context.organization, observation)
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    rescue ActiveRecord::RecordInvalid => e
      err(e.record.errors.full_messages.presence || e.message, code: "validation_failed")
    end

    private

    def company_for(context)
      org = context.organization
      org.respond_to?(:root_company) && org.root_company.present? ? org.root_company : org
    end

    def teammate_in_company_tree?(teammate, company)
      return false if teammate.nil?

      org = teammate.organization
      org.id == company.id || org.root_company&.id == company.id
    end

    def resolve_optional_goal(context, goal_path:, goal_id:)
      return nil if goal_path.blank? && goal_id.blank?

      goal = RecordPaths.resolve_goal(context, goal_path: goal_path, goal_id: goal_id)
      return nil if goal.nil?
      return nil unless goal.company_id == company_for(context).id
      return nil unless goal.can_be_viewed_by?(context.person)

      goal
    end
  end
end
