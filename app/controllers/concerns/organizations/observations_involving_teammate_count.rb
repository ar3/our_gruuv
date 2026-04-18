# frozen_string_literal: true

module Organizations
  # Shared count for observations index default filters, scoped to a teammate as "involving".
  # Used by employees (manager's view) and the per-teammate 1:1 area page.
  module ObservationsInvolvingTeammateCount
    extend ActiveSupport::Concern

    private

    # Matches Organizations::ObservationsController#base_filtered counting for default index params
    # (visibility + optional filters), scoped to observations involving a specific teammate.
    def observations_involving_teammate_total_count(teammate)
      return 0 if teammate.blank?

      query = ObservationsQuery.new(
        organization,
        { involving_teammate_id: teammate.id },
        current_person: current_person
      )

      filtered = query.base_scope
      filtered = query.filter_by_privacy_levels(filtered)
      filtered = query.filter_by_timeframe(filtered)
      filtered = query.filter_by_draft_status(filtered)
      filtered = query.filter_by_observer(filtered)
      filtered = query.filter_by_involving_teammate(filtered)
      filtered = query.filter_by_observee_ids(filtered)
      filtered = query.filter_by_rateable(filtered)
      filtered = query.filter_by_observation_type(filtered)
      filtered = query.filter_by_soft_deleted_status(filtered)

      filtered.count
    end
  end
end
