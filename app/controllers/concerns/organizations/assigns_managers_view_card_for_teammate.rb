# frozen_string_literal: true

module Organizations
  # Populates instance variables for organizations/employees/_managers_view on a single-teammate page.
  module AssignsManagersViewCardForTeammate
    extend ActiveSupport::Concern
    include Organizations::ObservationsInvolvingTeammateCount

    private

    def assign_managers_view_card_for_teammate
      return unless @teammate

      @filtered_and_paginated_teammates = [@teammate]
      @check_in_health_caches_by_teammate = CheckInHealthCache
        .where(teammate_id: @teammate.id, organization_id: organization.id)
        .index_by(&:teammate_id)
      @managers_view_observations_involving_counts_by_teammate_id =
        if Pundit.policy(pundit_user, company).view_observations?
          { @teammate.id => observations_involving_teammate_total_count(@teammate) }
        else
          {}
        end
    end
  end
end
