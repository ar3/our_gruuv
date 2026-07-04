# frozen_string_literal: true

module Organizations
  # Populates instance variables for organizations/employees/_managers_view on a single-teammate page.
  module AssignsManagersViewCardForTeammate
    extend ActiveSupport::Concern

    private

    def assign_managers_view_card_for_teammate
      return unless @teammate

      @filtered_and_paginated_teammates = [@teammate]
      @engagement_health_by_teammate_id = EngagementHealth::ClarityMetrics.records_by_teammate_id(
        organization: organization,
        teammate_ids: [@teammate.id]
      )
      @managers_view_row_data_by_teammate_id = ManagersViewCardDataService.load(
        teammates: [@teammate],
        organization: organization,
        viewing_teammate: current_company_teammate
      )
    end
  end
end
