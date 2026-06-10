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

      next_result = SingleItemCheckInNextItemService.call(
        teammate: teammate,
        organization: organization,
        current_person: perspective_person,
        current_type: :position,
        current_id: nil
      )

      ordered_items = next_result[:ordered_items].to_a
      latest_finalized_by_key = build_latest_finalized_by_item_key(ordered_items)

      ordered_items.sum do |item|
        latest_finalized = latest_finalized_by_key[item_key(item)]
        actions_needed_count(item: item, latest_finalized: latest_finalized, manager_perspective: manager_perspective)
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

    def actions_needed_count(item:, latest_finalized:, manager_perspective:)
      count = check_in_action_needed?(item) ? 1 : 0
      count += 1 if manager_perspective && finalize_action_needed?(latest_finalized)
      count
    end

    def check_in_action_needed?(item)
      item[:bucket]&.to_sym == :red && item[:my_side_completed_at].blank?
    end

    def finalize_action_needed?(latest_finalized)
      level = latest_finalized&.clarity_level || :obscured
      level.in?(%i[blurred obscured])
    end

    def build_latest_finalized_by_item_key(items)
      aspiration_ids = items.select { |i| i[:type] == :aspiration }.map { |i| i[:id] }.compact
      assignment_ids = items.select { |i| i[:type] == :assignment }.map { |i| i[:id] }.compact
      by_key = {}

      if aspiration_ids.any?
        AspirationCheckIn.where(company_teammate: teammate, aspiration_id: aspiration_ids)
          .closed
          .order(official_check_in_completed_at: :desc)
          .group_by(&:aspiration_id)
          .each { |id, rows| by_key[item_key(type: :aspiration, id: id)] = rows.first }
      end

      if assignment_ids.any?
        AssignmentCheckIn.where(company_teammate: teammate, assignment_id: assignment_ids)
          .closed
          .order(official_check_in_completed_at: :desc)
          .group_by(&:assignment_id)
          .each { |id, rows| by_key[item_key(type: :assignment, id: id)] = rows.first }
      end

      position_latest = PositionCheckIn.where(company_teammate: teammate).closed.order(official_check_in_completed_at: :desc).first
      by_key[item_key(type: :position, id: nil)] = position_latest if position_latest

      by_key
    end

    def item_key(item = nil, type: nil, id: nil)
      item_type = item ? item[:type] : type
      item_id = item ? item[:id] : id
      "#{item_type}:#{item_id || 'none'}"
    end
  end
end
