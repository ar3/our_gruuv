# frozen_string_literal: true

module CheckIns
  # Sum of clarity actions still needed on Up Next items for one perspective (employee or manager).
  class UpNextActionsCountService
    def self.call(teammate:, organization:, viewing_teammate:)
      new(teammate: teammate, organization: organization, viewing_teammate: viewing_teammate).call
    end

    def initialize(teammate:, organization:, viewing_teammate:)
      @teammate = teammate
      @organization = organization
      @viewing_teammate = viewing_teammate
    end

    def call
      perspective_person = perspective_person_for_count
      manager_perspective = perspective_person.id != teammate.person_id
      records = EngagementHealth::ClarityMetrics.records_for_teammate(
        organization: organization,
        teammate_id: teammate.id
      )
      eh_by_key = EngagementHealth::UpNextSupport.index_items_by_key(records)

      next_result = SingleItemCheckInNextItemService.call(
        teammate: teammate,
        organization: organization,
        current_person: perspective_person,
        current_type: :position,
        current_id: nil
      )

      next_result[:ordered_items].to_a.sum do |item|
        eh_item = eh_by_key[EngagementHealth::UpNextSupport.item_key(item)]
        eh_item ||= EngagementHealth::UpNextSupport.find_item(eh_by_key, item)
        EngagementHealth::UpNextSupport.actions_needed_count(eh_item, manager_perspective: manager_perspective)
      end
    end

    private

    attr_reader :teammate, :organization, :viewing_teammate

    def perspective_person_for_count
      if viewing_teammate&.id == teammate.id
        teammate.person
      else
        teammate.current_manager || viewing_teammate&.person
      end
    end
  end
end
