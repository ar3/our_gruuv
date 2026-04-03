module Observations
  class PublicKudosForRateable
    ALLOWED_RATEABLE_TYPES = %w[Assignment Ability Aspiration].freeze

    def self.call(organization:, rateable_type:, rateable_id:, limit: 20)
      relation(organization: organization, rateable_type: rateable_type, rateable_id: rateable_id)
        .limit(limit)
        .includes(:observer, { observed_teammates: :person }, :observation_ratings)
    end

    def self.relation(organization:, rateable_type:, rateable_id:)
      return Observation.none unless ALLOWED_RATEABLE_TYPES.include?(rateable_type.to_s)

      Observation
        .where(company_id: organization.id)
        .merge(Observation.published)
        .merge(Observation.kudos_observations)
        .where(privacy_level: %w[public_to_company public_to_world])
        .where(deleted_at: nil)
        .joins(:observation_ratings)
        .where(observation_ratings: { rateable_type: rateable_type.to_s, rateable_id: rateable_id })
        .distinct
        .order(observed_at: :desc)
    end
  end
end
