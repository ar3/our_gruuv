# frozen_string_literal: true

module Insights
  # Weekly scorecard rows for Insights: OG Scorecard (metric metadata + per-week values).
  class OgScorecardBuilder
    METADATA = {
      active_teammates: {
        label: 'Number of active teammates',
        yellow: nil,
        green: nil,
        direction: :more
      },
      unique_ogo_publishers: {
        label: 'Number of unique teammates that published an OGO',
        yellow: nil,
        green: nil,
        direction: :more
      },
      unique_ogo_observees: {
        label: 'Number of unique teammates named as observees in an OGO',
        yellow: nil,
        green: nil,
        direction: :more
      }
    }.freeze

    def initialize(company:, week_starts:, chart_range:)
      @company = company
      @week_starts = week_starts
      @chart_range = chart_range
    end

    def call
      active_by_week = active_teammate_counts_by_week
      publishers_by_week, observees_by_week = observation_distinct_sets_by_week

      {
        groups: [
          {
            title: 'Teammates',
            rows: [build_row(:active_teammates, active_by_week)]
          },
          {
            title: 'Observations',
            rows: [
              build_row(:unique_ogo_publishers, publishers_by_week),
              build_row(:unique_ogo_observees, observees_by_week)
            ]
          }
        ]
      }
    end

    private

    attr_reader :company, :week_starts, :chart_range

    def build_row(key, counts_by_week)
      meta = METADATA.fetch(key)
      weekly_values = week_starts.map { |wk| counts_by_week[wk] || 0 }
      {
        key: key,
        label: meta[:label],
        yellow: meta[:yellow],
        green: meta[:green],
        direction: meta[:direction],
        six_week_avg: average_last_n(weekly_values, 6),
        weekly_values: weekly_values
      }
    end

    def average_last_n(values, n)
      return nil if values.empty?

      tail = values.last(n)
      (tail.sum.to_f / tail.size).round(1)
    end

    def active_teammate_counts_by_week
      rows = CompanyTeammate
        .for_organization_hierarchy(company)
        .where.not(first_employed_at: nil)
        .pluck(:first_employed_at, :last_terminated_at)

      week_starts.index_with do |week_start|
        week_end_time = (week_start + 6.days).in_time_zone.end_of_day
        rows.count { |first_employed_at, last_terminated_at|
          employed_on_or_before?(first_employed_at, week_end_time) &&
            not_terminated_before?(last_terminated_at, week_end_time)
        }
      end
    end

    def employed_on_or_before?(first_employed_at, week_end_time)
      return false if first_employed_at.blank?

      first_employed_at.to_time.in_time_zone <= week_end_time
    end

    def not_terminated_before?(last_terminated_at, week_end_time)
      last_terminated_at.nil? || last_terminated_at.to_time.in_time_zone > week_end_time
    end

    def observation_distinct_sets_by_week
      publishers_by_week = week_starts.index_with { Set.new }
      observees_by_week = week_starts.index_with { Set.new }
      week_set = week_starts.to_set

      obs_scope = Observation
        .for_company(company)
        .not_soft_deleted
        .published
        .where(published_at: chart_range)

      obs_rows = obs_scope.pluck(:published_at, :observer_id)
      observer_person_ids = obs_rows.map(&:last).compact.uniq
      teammate_id_by_person_id = teammate_id_by_person(observer_person_ids)

      obs_rows.each do |published_at, observer_person_id|
        next if published_at.blank? || observer_person_id.blank?

        wk = week_key_for(published_at)
        next unless week_set.include?(wk)

        tid = teammate_id_by_person_id[observer_person_id]
        publishers_by_week[wk] << tid if tid
      end

      observee_rows = Observee
        .joins(:observation)
        .merge(obs_scope)
        .pluck('observations.published_at', 'observees.teammate_id')

      observee_rows.each do |published_at, teammate_id|
        next if published_at.blank? || teammate_id.blank?

        wk = week_key_for(published_at)
        next unless week_set.include?(wk)

        observees_by_week[wk] << teammate_id
      end

      [
        publishers_by_week.transform_values(&:size),
        observees_by_week.transform_values(&:size)
      ]
    end

    def week_key_for(time)
      time.in_time_zone.to_date.beginning_of_week(:monday)
    end

    def teammate_id_by_person(person_ids)
      return {} if person_ids.empty?

      CompanyTeammate
        .for_organization_hierarchy(company)
        .where(person_id: person_ids)
        .pluck(:person_id, :id)
        .group_by(&:first)
        .transform_values { |pairs| pairs.map(&:last).last }
    end
  end
end
