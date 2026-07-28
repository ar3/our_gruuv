# frozen_string_literal: true

module AgentTools
  # Creates a draft Observation only (published_at: nil). No publish / update / destroy.
  class CreateDraftObservation < Base
    include Rails.application.routes.url_helpers

    TRIGGER_SOURCE = "ask_og"
    TRIGGER_TYPE = "ask_og_assistant"
    ALLOWED_TYPES = %w[kudos feedback quick_note].freeze
    CREATED_AS = "ask_og"

    def call(
      context:,
      observee_path: nil,
      observee_teammate_id: nil,
      story: nil,
      observation_type: "feedback",
      privacy_level: "observed_and_managers",
      goal_path: nil,
      goal_id: nil,
      **_ignored
    )
      context.authorize!(Observation.new(company: company_for(context)), :create?)

      observee = RecordPaths.resolve_teammate(
        context,
        observee_path: observee_path,
        observee_teammate_id: observee_teammate_id
      )
      return err("observee path is required") if observee_path.blank? && observee_teammate_id.blank?
      return err("observee teammate not found") if observee.nil?
      return err("observee not in organization") unless teammate_in_company_tree?(observee, company_for(context))

      kind = ALLOWED_TYPES.include?(observation_type.to_s) ? observation_type.to_s : "feedback"
      company = company_for(context)
      linked_goal = resolve_optional_goal(context, goal_path: goal_path, goal_id: goal_id)

      observation = nil
      ActiveRecord::Base.transaction do
        trigger = ObservationTrigger.create!(
          trigger_source: TRIGGER_SOURCE,
          trigger_type: TRIGGER_TYPE,
          trigger_data: {
            "created_via" => "ask_og",
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
          created_as_type: CREATED_AS,
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
      err(e.message)
    rescue ActiveRecord::RecordInvalid => e
      err(e.record.errors.full_messages.presence || e.message)
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
