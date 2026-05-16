# frozen_string_literal: true

module Insights
  module OgScorecard
    # Loads check-in and tenure data once for OG Scorecard check-in clarity metrics.
    class CheckInDataPreloader
      def initialize(company)
        @company = company
      end

      def load
        teammate_ids = CompanyTeammate
          .for_organization_hierarchy(company)
          .where.not(first_employed_at: nil)
          .pluck(:id)

        aspiration_ids = Aspiration.within_hierarchy(company).pluck(:id)

        {
          teammates: CompanyTeammate
            .where(id: teammate_ids)
            .pluck(:id, :first_employed_at, :last_terminated_at),
          employment_tenures: EmploymentTenure
            .where(company: company, teammate_id: teammate_ids)
            .pluck(:teammate_id, :started_at, :ended_at, :position_id),
          assignment_tenures: AssignmentTenure
            .joins(:assignment)
            .where(teammate_id: teammate_ids, assignments: { company_id: company_ids_in_hierarchy })
            .pluck(:teammate_id, :assignment_id, :started_at, :ended_at, :anticipated_energy_percentage),
          required_assignment_ids_by_position: required_assignment_ids_by_position_id,
          aspiration_ids: aspiration_ids,
          position_finalized_at: latest_check_in_times(
            PositionCheckIn.where(teammate_id: teammate_ids).closed
          ),
          assignment_finalized_at: latest_check_in_times_by_assignment(
            AssignmentCheckIn.where(teammate_id: teammate_ids).closed
          ),
          aspiration_finalized_at: latest_check_in_times_by_aspiration(
            AspirationCheckIn.where(teammate_id: teammate_ids, aspiration_id: aspiration_ids).closed
          )
        }
      end

      private

      attr_reader :company

      def company_ids_in_hierarchy
        @company_ids_in_hierarchy ||= company.self_and_descendants.pluck(:id)
      end

      def required_assignment_ids_by_position_id
        position_ids = Position.joins(:title).where(titles: { company_id: company.id }).pluck(:id)
        return {} if position_ids.empty?

        PositionAssignment
          .where(position_id: position_ids, assignment_type: 'required')
          .pluck(:position_id, :assignment_id)
          .group_by(&:first)
          .transform_values { |pairs| pairs.map(&:last) }
      end

      def latest_check_in_times(scope)
        scope
          .where.not(official_check_in_completed_at: nil)
          .pluck(:teammate_id, :official_check_in_completed_at)
          .group_by(&:first)
          .transform_values { |rows| rows.map(&:last) }
      end

      def latest_check_in_times_by_assignment(scope)
        scope
          .where.not(official_check_in_completed_at: nil)
          .pluck(:teammate_id, :assignment_id, :official_check_in_completed_at)
          .group_by { |tid, aid, _| [tid, aid] }
          .transform_values { |rows| rows.map { |r| r[2] } }
      end

      def latest_check_in_times_by_aspiration(scope)
        scope
          .where.not(official_check_in_completed_at: nil)
          .pluck(:teammate_id, :aspiration_id, :official_check_in_completed_at)
          .group_by { |tid, aid, _| [tid, aid] }
          .transform_values { |rows| rows.map { |r| r[2] } }
      end
    end
  end
end
