# frozen_string_literal: true

module Insights
  # Insights: Real OG Leaders — ranks authors of published, non-journal OGOs about
  # someone else with kudos and/or constructive-feedback completion in a timeframe.
  class RealOgLeadersBuilder
    Entry = Struct.new(
      :person,
      :company_teammate,
      :kudos_count,
      :constructive_count,
      :has_kudos,
      :has_constructive,
      :has_both,
      :total_count,
      :most_recent_at,
      :display_name,
      keyword_init: true
    )

    def initialize(company:, range: nil)
      @company = company
      @range = range
    end

    def call
      observations = load_qualifying_observations
      return [] if observations.empty?

      stats_by_observer_id = aggregate(observations)
      persons_by_id = Person.where(id: stats_by_observer_id.keys).index_by(&:id)
      teammates_by_person_id = CompanyTeammate
        .where(organization: @company, person_id: stats_by_observer_id.keys)
        .index_by(&:person_id)

      stats_by_observer_id.filter_map do |observer_id, stats|
        person = persons_by_id[observer_id]
        next unless person

        has_kudos = stats[:kudos_count].positive?
        has_constructive = stats[:constructive_count].positive?
        next unless has_kudos || has_constructive

        Entry.new(
          person: person,
          company_teammate: teammates_by_person_id[observer_id],
          kudos_count: stats[:kudos_count],
          constructive_count: stats[:constructive_count],
          has_kudos: has_kudos,
          has_constructive: has_constructive,
          has_both: has_kudos && has_constructive,
          total_count: stats[:kudos_count] + stats[:constructive_count],
          most_recent_at: stats[:most_recent_at],
          display_name: person.display_name
        )
      end.sort_by { |entry| sort_key(entry) }
    end

    # Mirrors Observations insights "kudos" / "constructive feedback" OGO buckets for
    # authored published OGOs, but only when ratings exist that pin the side:
    # - kudos: any positive rating and no negative
    # - constructive: at least one negative rating
    # - nil: no ratings (or only N/A) — does not count toward either check
    def self.side_for(observation)
      ratings = observation.observation_ratings
      has_positive = ratings.any?(&:positive?)
      has_negative = ratings.any?(&:negative?)
      return :kudos if has_positive && !has_negative
      return :constructive if has_negative

      nil
    end

    private

    def load_qualifying_observations
      scope = Observation
        .for_company(@company)
        .not_soft_deleted
        .published
        .not_journal
        .where.not(id: self_as_observee_observation_ids)
        .includes(:observation_ratings)

      scope = scope.where(observed_at: @range) if @range
      scope.to_a
    end

    def self_as_observee_observation_ids
      # CompanyTeammate table is `teammates` (not company_teammates).
      Observee
        .joins(:company_teammate, :observation)
        .where(observations: { company_id: @company.id })
        .where("teammates.person_id = observations.observer_id")
        .select(:observation_id)
    end

    def aggregate(observations)
      observations.each_with_object({}) do |observation, stats|
        side = self.class.side_for(observation)
        next unless side

        bucket = stats[observation.observer_id] ||= {
          kudos_count: 0,
          constructive_count: 0,
          most_recent_at: nil
        }
        bucket[:"#{side}_count"] += 1
        event_at = observation.published_at || observation.observed_at
        if bucket[:most_recent_at].nil? || event_at > bucket[:most_recent_at]
          bucket[:most_recent_at] = event_at
        end
      end
    end

    # Both → constructive-only → kudos-only; then total desc, most recent desc, name.
    def sort_key(entry)
      group =
        if entry.has_both
          0
        elsif entry.has_constructive
          1
        else
          2
        end
      [
        group,
        -entry.total_count,
        -(entry.most_recent_at&.to_i || 0),
        entry.display_name.to_s.downcase
      ]
    end
  end
end
