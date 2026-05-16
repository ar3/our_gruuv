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

      ObservationsQuery.new(
        company,
        { involving_teammate_id: teammate.id },
        current_person: current_person
      ).call.count
    end
  end
end
