# frozen_string_literal: true

module Insights
  # Weekly stacked series of published OGOs by Internal vs External observer.
  class ObservationsInternalExternalChart
    Affil = ObservationsObserverAffiliation

    def self.call(base_scope:, chart_range:, organization:)
      new(base_scope: base_scope, chart_range: chart_range, organization: organization).call
    end

    def initialize(base_scope:, chart_range:, organization:)
      @base_scope = base_scope
      @chart_range = chart_range
      @organization = organization
    end

    def call
      return empty_result unless @chart_range

      scope = @base_scope.where(observed_at: @chart_range)
      observation_rows = scope.pluck(:id, :observed_at, :observer_id)
      observer_ids = observation_rows.map { |_id, _at, oid| oid }.uniq.compact
      teammate_ids = Affil.teammate_person_ids(organization: @organization, person_ids: observer_ids)

      end_date = @chart_range.end.to_date
      start_date = @chart_range.begin.to_date
      week_dates = (start_date..end_date).to_a.map { |d| d.beginning_of_week }.uniq.sort
      categories = week_dates.map { |w| w.strftime('%b %d, %Y') }

      labels = [Affil::INTERNAL_LABEL, Affil::EXTERNAL_LABEL]
      week_counts = week_dates.map do |week_start|
        week_end_time = (week_start + 6.days).to_time.end_of_day
        week_start_time = week_start.to_time.beginning_of_day
        counts = Hash.new(0)
        observation_rows.each do |_obs_id, observed_at, observer_id|
          next unless observed_at && observed_at >= week_start_time && observed_at <= week_end_time

          counts[Affil.affiliation_label(observer_id, teammate_ids)] += 1
        end
        counts
      end

      series = labels.map do |label|
        { name: label, data: week_counts.map { |counts| counts[label] || 0 } }
      end

      { categories: categories, series: series }
    end

    private

    def empty_result
      { categories: [], series: [] }
    end
  end
end
