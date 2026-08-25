# frozen_string_literal: true

module Insights
  # Living values (OGO volume per Aspiration) + champions leaderboards.
  # Aggregates include private OGOs; public boards only list people with ≥1 public OGO
  # and score those people on public OGOs only.
  class ValuesLivingAndChampionsQuery
    PUBLIC_LEVELS = %w[public_to_company public_to_world].freeze
    PRIVATE_LEVELS = %w[observed_only managers_only observed_and_managers].freeze
    COUNTED_LEVELS = (PRIVATE_LEVELS + PUBLIC_LEVELS).freeze
    TOP_N = 10

    ChampionRow = Struct.new(:teammate, :ogo_count, :points, keyword_init: true)
    ValueSection = Struct.new(
      :aspiration,
      :total_ogo_count,
      :public_ogo_count,
      :private_ogo_count,
      :top_observees,
      :top_observers,
      keyword_init: true
    )

    def initialize(company:, published_at_range: nil)
      @company = company
      @published_at_range = published_at_range
    end

    def sections
      @sections ||= build_sections
    end

    def living_ranked
      sections.sort_by { |section| [-section.total_ogo_count, section.aspiration.sort_order.to_i, section.aspiration.name.to_s.downcase] }
    end

    private

    attr_reader :company, :published_at_range

    def build_sections
      aspirations = Aspiration.for_company(company).includes(:department).ordered.to_a
      return [] if aspirations.empty?

      aspiration_ids = aspirations.map(&:id)
      total_by_aspiration = Hash.new(0)
      public_by_aspiration = Hash.new(0)
      private_by_aspiration = Hash.new(0)

      # observee_counts[aspiration_id][teammate_id] = public ogo count
      observee_counts = Hash.new { |h, k| h[k] = Hash.new(0) }
      observer_counts = Hash.new { |h, k| h[k] = Hash.new(0) }
      # points[aspiration_id][teammate_id]
      observee_points = Hash.new { |h, k| h[k] = Hash.new(0.0) }
      observer_points = Hash.new { |h, k| h[k] = Hash.new(0.0) }

      observation_aspiration_rows = rated_observation_aspiration_pairs(aspiration_ids)
      observation_ids = observation_aspiration_rows.map { |row| row[:observation_id] }.uniq
      points_by_observation_teammate = points_received_by_observation_teammate(observation_ids)
      points_by_observation = points_by_observation_teammate.each_with_object(Hash.new(0.0)) do |((obs_id, _tm_id), pts), h|
        h[obs_id] += pts
      end

      observees_by_observation = load_observees_by_observation(observation_ids)

      observation_aspiration_rows.each do |row|
        aspiration_id = row[:aspiration_id]
        observation_id = row[:observation_id]
        public = row[:public]

        total_by_aspiration[aspiration_id] += 1
        if public
          public_by_aspiration[aspiration_id] += 1
        else
          private_by_aspiration[aspiration_id] += 1
          next
        end

        observer_person_id = row[:observer_id]
        observer_teammate_id = row[:observer_teammate_id]
        if observer_teammate_id
          observer_counts[aspiration_id][observer_teammate_id] += 1
          observer_points[aspiration_id][observer_teammate_id] += points_by_observation[observation_id]
        end

        Array(observees_by_observation[observation_id]).each do |observee|
          next if observee[:person_id] == observer_person_id

          teammate_id = observee[:teammate_id]
          observee_counts[aspiration_id][teammate_id] += 1
          observee_points[aspiration_id][teammate_id] += points_by_observation_teammate[[observation_id, teammate_id]].to_f
        end
      end

      teammate_ids = (
        observee_counts.values.flat_map(&:keys) + observer_counts.values.flat_map(&:keys)
      ).uniq
      teammates_by_id = load_teammates(teammate_ids)

      aspirations.map do |aspiration|
        ValueSection.new(
          aspiration: aspiration,
          total_ogo_count: total_by_aspiration[aspiration.id],
          public_ogo_count: public_by_aspiration[aspiration.id],
          private_ogo_count: private_by_aspiration[aspiration.id],
          top_observees: top_rows(observee_counts[aspiration.id], observee_points[aspiration.id], teammates_by_id),
          top_observers: top_rows(observer_counts[aspiration.id], observer_points[aspiration.id], teammates_by_id)
        )
      end
    end

    def top_rows(counts_by_teammate, points_by_teammate, teammates_by_id)
      counts_by_teammate
        .filter_map do |teammate_id, ogo_count|
          teammate = teammates_by_id[teammate_id]
          next unless teammate

          ChampionRow.new(
            teammate: teammate,
            ogo_count: ogo_count,
            points: points_by_teammate[teammate_id].to_f
          )
        end
        .sort_by { |row| [-row.ogo_count, -row.points, row.teammate.person.display_name.to_s.downcase] }
        .first(TOP_N)
    end

    # One row per (observation, aspiration) — living counts OGOs, not observee pairs.
    def rated_observation_aspiration_pairs(aspiration_ids)
      scope = ObservationRating
        .joins(:observation)
        .joins(<<~SQL.squish)
          LEFT JOIN teammates observer_teammates
            ON observer_teammates.person_id = observations.observer_id
           AND observer_teammates.organization_id = observations.company_id
        SQL
        .where(rateable_type: 'Aspiration', rateable_id: aspiration_ids)
        .where.not(rating: 'na')
        .merge(
          Observation
            .for_company(company)
            .not_soft_deleted
            .published
            .not_journal
            .where(privacy_level: COUNTED_LEVELS)
        )

      scope = scope.where(observations: { published_at: published_at_range }) if published_at_range

      scope
        .pluck(
          'observations.id',
          'observation_ratings.rateable_id',
          'observations.privacy_level',
          'observations.observer_id',
          'observer_teammates.id'
        )
        .uniq { |observation_id, aspiration_id, *_rest| [observation_id, aspiration_id] }
        .map do |observation_id, aspiration_id, privacy_level, observer_id, observer_teammate_id|
          {
            observation_id: observation_id,
            aspiration_id: aspiration_id,
            public: PUBLIC_LEVELS.include?(privacy_level.to_s),
            observer_id: observer_id,
            observer_teammate_id: observer_teammate_id
          }
        end
    end

    def load_observees_by_observation(observation_ids)
      return {} if observation_ids.empty?

      Observee
        .joins(:company_teammate)
        .where(observation_id: observation_ids)
        .pluck('observees.observation_id', 'observees.teammate_id', 'teammates.person_id')
        .each_with_object(Hash.new { |h, k| h[k] = [] }) do |(observation_id, teammate_id, person_id), hash|
          hash[observation_id] << { teammate_id: teammate_id, person_id: person_id }
        end
    end

    def points_received_by_observation_teammate(observation_ids)
      return {} if observation_ids.empty?

      PointsExchangeTransaction
        .where(observation_id: observation_ids, organization_id: company.id)
        .group(:observation_id, :company_teammate_id)
        .sum(:points_to_spend_delta)
        .transform_values(&:to_f)
    end

    def load_teammates(teammate_ids)
      return {} if teammate_ids.empty?

      CompanyTeammate
        .where(id: teammate_ids)
        .includes(:person)
        .index_by(&:id)
    end
  end
end
