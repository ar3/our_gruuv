# frozen_string_literal: true

module AgentTools
  # Observations via ObservationsQuery (visibility baked in). Never raw Observation.where.
  class ListObservations < Base
    DEFAULT_LIMIT = 20

    def call(context:, query: nil, limit: DEFAULT_LIMIT, offset: 0, **_ignored)
      context.authorize!(context.organization, :show?)

      relation = ObservationsQuery.new(
        context.organization,
        { draft: "false" },
        current_person: context.person
      ).call

      observations, = ListPagination.scan_relation(relation)
      needle = query.to_s.strip.downcase
      if needle.present?
        observations = observations.select { |o| o.story.to_s.downcase.include?(needle) }
      end

      visible = observations.select do |observation|
        Pundit.policy(context.pundit_user, observation).show?
      end
      page = ListPagination.slice(visible, limit: limit, offset: offset)

      ok(
        { observations: page[:items].map { |o| serialize(context, o) } }.merge(page[:meta])
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    end

    private

    def serialize(context, observation)
      {
        story_preview: observation.story.to_s.truncate(160),
        observation_type: observation.observation_type,
        observer_name: observation.observer&.display_name,
        observed_at: observation.observed_at&.iso8601,
        draft: observation.draft?,
        path: RecordPaths.observation_path(context, observation)
      }
    end
  end
end
