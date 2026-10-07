# frozen_string_literal: true

module AgentTools
  # Single observation (OGO) by path (preferred) or id — fully hydrated for analysis.
  class GetObservation < Base
    def call(context:, path: nil, observation_path: nil, observation_id: nil, **_ignored)
      context.authorize!(context.organization, :show?)
      company = company_for(context)

      if path.blank? && observation_path.blank? && observation_id.blank?
        return err("path is required", code: "validation_failed")
      end

      observation = RecordPaths.resolve_observation(
        context,
        path: path,
        observation_path: observation_path,
        observation_id: observation_id
      )
      return err("observation not found", code: "not_found") if observation.nil?
      return err("observation not in organization", code: "validation_failed") unless observation.company_id == company.id

      context.authorize!(observation, :show?)

      observation = Observation.includes(
        :observer,
        :goal,
        { observed_teammates: :person },
        :observation_ratings
      ).find(observation.id)
      preload_rateables(observation)

      ok(
        observation: serialize(context, observation, company: company),
        note:
          "Full OGO for analysis. Ratings are Ability/Assignment/Aspiration " \
          "(rateable_type, rateable_id, name, path, rating, rating_label). " \
          "Milestone prose: get_ability. Assignment body: get_assignment. " \
          "List with timeframe / rateable_path via list_observations."
      )
    rescue AgentTools::NotAuthorized => e
      err(e.message, code: "not_authorized")
    end

    private

    def company_for(context)
      org = context.organization
      org.respond_to?(:root_company) && org.root_company.present? ? org.root_company : org
    end

    def preload_rateables(observation)
      observation.observation_ratings.group_by(&:rateable_type).each do |rateable_type, ratings|
        ids = ratings.map(&:rateable_id).uniq
        next if ids.empty?

        case rateable_type
        when "Assignment" then Assignment.where(id: ids).load
        when "Ability" then Ability.where(id: ids).load
        when "Aspiration" then Aspiration.where(id: ids).load
        end
      end
    end

    def serialize(context, observation, company:)
      {
        path: RecordPaths.observation_path(context, observation),
        story: observation.story,
        observation_type: observation.observation_type,
        privacy_level: observation.privacy_level,
        draft: observation.draft?,
        published_at: observation.published_at&.iso8601,
        observed_at: observation.observed_at&.iso8601,
        primary_feeling: observation.primary_feeling,
        secondary_feeling: observation.secondary_feeling,
        feelings_display: observation.feelings_display,
        created_as_type: observation.created_as_type,
        observer: serialize_observer(context, observation, company: company),
        observees: observation.observed_teammates.map { |t| serialize_teammate(context, t) },
        ratings: observation.observation_ratings.map { |r| serialize_rating(context, r) },
        goal: serialize_goal(context, observation.goal)
      }
    end

    def serialize_observer(context, observation, company:)
      person = observation.observer
      teammate = person&.company_teammates&.find_by(organization_id: company.id)
      {
        name: person&.display_name,
        path: teammate ? RecordPaths.teammate_path(context, teammate) : nil
      }
    end

    def serialize_teammate(context, teammate)
      {
        name: teammate.person&.display_name,
        path: RecordPaths.teammate_path(context, teammate)
      }
    end

    def serialize_rating(context, rating)
      rateable = rating.rateable
      {
        rateable_type: rating.rateable_type,
        rateable_id: rating.rateable_id,
        name: rateable_name(rateable),
        path: rateable ? RecordPaths.path_for_rateable(context, rateable) : nil,
        rating: rating.rating,
        rating_label: rating.display_label
      }
    end

    def rateable_name(rateable)
      case rateable
      when Ability, Aspiration then rateable.name
      when Assignment then rateable.title
      else rateable&.to_s
      end
    end

    def serialize_goal(context, goal)
      return nil unless goal

      {
        title: goal.title,
        path: RecordPaths.goal_path(context, goal)
      }
    end
  end
end
