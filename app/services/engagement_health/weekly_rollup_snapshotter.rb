# frozen_string_literal: true

module EngagementHealth
  # Persists category rollup rows for one completed Sunday. Item-level detail
  # stays in engagement_health_statuses (live cache only).
  class WeeklyRollupSnapshotter
    def self.call(organization:, week_ending_on:, teammate_ids: nil)
      new(organization: organization, week_ending_on: week_ending_on, teammate_ids: teammate_ids).call
    end

    def initialize(organization:, week_ending_on:, teammate_ids: nil)
      @organization = organization
      @week_ending_on = week_ending_on.to_date
      @teammate_ids = teammate_ids
    end

    def call
      reference_time = week_ending_on.in_time_zone.end_of_day
      computed_at = Time.current
      teammate_records = load_teammates(reference_time)

      EngagementHealthWeeklyRollup.transaction do
        teammate_records.each do |teammate|
          category_rows(teammate, reference_time).each do |category, status|
            upsert_rollup(teammate, category, status, computed_at)
          end
        end
      end
    end

    private

    attr_reader :organization, :week_ending_on, :teammate_ids

    def load_teammates(reference_time)
      ids = WeeklyRollupTeammateScope.active_teammate_ids(
        organization: organization,
        week_ending_on: week_ending_on,
        teammate_ids: teammate_ids
      )
      return [] if ids.empty?

      CompanyTeammate.where(id: ids).to_a
    end

    def category_rows(teammate, reference_time)
      Calculator
        .call(teammate: teammate, organization: organization, reference_time: reference_time)
        .select { |row| row[:level] == "category" }
        .to_h { |row| [row[:category], row[:status]] }
    end

    def upsert_rollup(teammate, category, status, computed_at)
      record = EngagementHealthWeeklyRollup.find_or_initialize_by(
        teammate: teammate,
        organization: organization,
        week_ending_on: week_ending_on,
        category: category
      )
      record.status = status
      record.computed_at = computed_at
      record.save!
    end
  end
end
