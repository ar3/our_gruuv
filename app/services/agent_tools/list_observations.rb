# frozen_string_literal: true

module AgentTools
  # Observations via ObservationsQuery (visibility baked in). Never raw Observation.where.
  class ListObservations < Base
    DEFAULT_LIMIT = 20
    TIMEFRAMES = %w[
      this_week
      this_month
      this_quarter
      last_45_days
      last_90_days
      this_year
      between
    ].freeze
    OBSERVATION_TYPES = %w[kudos feedback quick_note generic].freeze

    def call(
      context:,
      query: nil,
      timeframe: nil,
      timeframe_start_date: nil,
      timeframe_end_date: nil,
      rateable_path: nil,
      rateable_type: nil,
      rateable_id: nil,
      observation_type: nil,
      limit: DEFAULT_LIMIT,
      offset: 0,
      **_ignored
    )
      context.authorize!(context.organization, :show?)
      company = company_for(context)

      query_params = { draft: "false" }

      tf = timeframe.to_s.presence
      if tf.present?
        return err("invalid timeframe", code: "validation_failed") unless TIMEFRAMES.include?(tf)

        query_params[:timeframe] = tf
        if tf == "between"
          query_params[:timeframe_start_date] = timeframe_start_date.to_s.presence
          query_params[:timeframe_end_date] = timeframe_end_date.to_s.presence
          if query_params[:timeframe_start_date].blank? || query_params[:timeframe_end_date].blank?
            return err("timeframe between requires timeframe_start_date and timeframe_end_date", code: "validation_failed")
          end
        end
      end

      rateable = nil
      if rateable_path.present? || rateable_type.present? || rateable_id.present?
        rateable = RecordPaths.resolve_rateable(
          context,
          rateable_path: rateable_path,
          rateable_type: rateable_type,
          rateable_id: rateable_id
        )
        return err("rateable not found", code: "not_found") if rateable.nil?
        unless rateable.respond_to?(:company_id) && rateable.company_id == company.id
          return err("rateable not in organization", code: "validation_failed")
        end

        query_params[:rateable_type] = rateable.class.name
        query_params[:rateable_id] = rateable.id
      end

      ot = observation_type.to_s.presence
      if ot.present?
        return err("invalid observation_type", code: "validation_failed") unless OBSERVATION_TYPES.include?(ot)

        query_params[:observation_type] = ot
      end

      relation = ObservationsQuery.new(
        context.organization,
        query_params,
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
        {
          observations: page[:items].map { |o| serialize(context, o) },
          filters: {
            query: query.to_s.strip.presence,
            timeframe: tf,
            timeframe_start_date: query_params[:timeframe_start_date],
            timeframe_end_date: query_params[:timeframe_end_date],
            rateable_path: rateable_path.presence,
            rateable_type: rateable&.class&.name,
            rateable_id: rateable&.id,
            observation_type: ot
          }.compact,
          note:
            "Thin list rows (story_preview). Hydrate one OGO with get_observation(path=...). " \
            "Filters: timeframe, rateable_path (Ability/Assignment/Aspiration), observation_type, story query."
        }.merge(page[:meta])
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    end

    private

    def company_for(context)
      org = context.organization
      org.respond_to?(:root_company) && org.root_company.present? ? org.root_company : org
    end

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
