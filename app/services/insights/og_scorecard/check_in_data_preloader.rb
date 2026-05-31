# frozen_string_literal: true

module Insights
  module OgScorecard
    # Loads check-in and tenure data once for OG Scorecard check-in clarity metrics.
    class CheckInDataPreloader
      def initialize(company, teammate_ids: nil)
        @company = company
        @teammate_ids = teammate_ids
      end

      def load
        teammate_ids_list = scoped_teammate_ids

        aspiration_ids = Aspiration.within_hierarchy(company).pluck(:id)

        {
          teammates: CompanyTeammate
            .where(id: teammate_ids_list)
            .pluck(:id, :first_employed_at, :last_terminated_at),
          employment_tenures: EmploymentTenure
            .where(company: company, teammate_id: teammate_ids_list)
            .pluck(:teammate_id, :started_at, :ended_at, :position_id),
          assignment_tenures: AssignmentTenure
            .joins(:assignment)
            .where(teammate_id: teammate_ids_list, assignments: { company_id: company_ids_in_hierarchy })
            .pluck(:teammate_id, :assignment_id, :started_at, :ended_at, :anticipated_energy_percentage),
          required_assignment_ids_by_position: required_assignment_ids_by_position_id,
          aspiration_ids: aspiration_ids,
          position_finalized_at: latest_check_in_times(
            PositionCheckIn.where(teammate_id: teammate_ids_list).closed
          ),
          assignment_finalized_at: latest_check_in_times_by_assignment(
            AssignmentCheckIn.where(teammate_id: teammate_ids_list).closed
          ),
          aspiration_finalized_at: latest_check_in_times_by_aspiration(
            AspirationCheckIn.where(teammate_id: teammate_ids_list, aspiration_id: aspiration_ids).closed
          )
        }
      end

      private

      attr_reader :company, :teammate_ids

      def scoped_teammate_ids
        scope = CompanyTeammate
          .for_organization_hierarchy(company)
          .where.not(first_employed_at: nil)
        scope = scope.where(id: teammate_ids) if teammate_ids
        scope.pluck(:id)
      end

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
