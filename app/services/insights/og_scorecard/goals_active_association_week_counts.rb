# frozen_string_literal: true

module Insights
  module OgScorecard
    # Unique teammates with an active owned goal linked to an Assignment or Aspiration (Aspirational Value).
    class GoalsActiveAssociationWeekCounts
      ASSOCIABLE_TYPES = {
        aspiration: 'Aspiration',
        assignment: 'Assignment'
      }.freeze

      def self.call(company:, week_starts:, associable_type:)
        new(company: company, week_starts: week_starts, associable_type: associable_type).call
      end

      def initialize(company:, week_starts:, associable_type:)
        @company = company
        @week_starts = week_starts
        @associable_type = ASSOCIABLE_TYPES.fetch(associable_type.to_sym)
      end

      def call
        week_starts.index_with do |week_start|
          reference_time = (week_start + 6.days).in_time_zone.end_of_day
          active_ids = active_teammate_ids_at(reference_time)
          next 0 if active_ids.empty?

          associable_ids = associable_ids_for_company
          next 0 if associable_ids.empty?

          Goal
            .where(company: company, owner_type: 'CompanyTeammate', owner_id: active_ids)
            .merge(active_at(reference_time))
            .joins(:goal_associations)
            .where(goal_associations: { associable_type: associable_type, associable_id: associable_ids })
            .distinct
            .count(:owner_id)
        end
      end

      private

      attr_reader :company, :week_starts, :associable_type

      def active_teammate_ids_at(reference_time)
        CompanyTeammate
          .for_organization_hierarchy(company)
          .where.not(first_employed_at: nil)
          .pluck(:id, :first_employed_at, :last_terminated_at)
          .filter_map do |id, first_employed_at, last_terminated_at|
            next unless employed_at?(first_employed_at, last_terminated_at, reference_time)

            id
          end
      end

      def employed_at?(first_employed_at, last_terminated_at, reference_time)
        return false if first_employed_at.blank?

        first_employed_at.to_time.in_time_zone <= reference_time &&
          (last_terminated_at.nil? || last_terminated_at.to_time.in_time_zone > reference_time)
      end

      def associable_ids_for_company
        case associable_type
        when 'Aspiration'
          Aspiration.within_hierarchy(company).pluck(:id)
        when 'Assignment'
          Assignment.where(company: company).pluck(:id)
        else
          []
        end
      end

      def active_at(reference_time)
        Goal
          .where(deleted_at: nil)
          .where.not(started_at: nil)
          .where('started_at <= ?', reference_time)
          .where('completed_at IS NULL OR completed_at > ?', reference_time)
      end
    end
  end
end
