# frozen_string_literal: true

module CheckIns
  # Returns the next single-item check-in target (aspiration, assignment, or position)
  # and whether the "Save and move to next" button should be enabled.
  #
  # Urgency buckets match EngagementHealth Required Clarity (Healthy / Warning /
  # Needs Attention) from latest official finalization — same windows as Up Next
  # and the all-fresh banner. When every item is Healthy, next_requires_check_in
  # is false ("fully up to date" on the hub CTA).
  class SingleItemCheckInNextItemService
    BUCKET_RED = :red       # Needs Attention (never or 90+ days)
    BUCKET_YELLOW = :yellow # Warning (61–89 days)
    BUCKET_GREEN = :green   # Healthy (finalized within 60 days)

    def self.call(teammate:, organization:, current_person:, current_type:, current_id: nil)
      new(
        teammate: teammate,
        organization: organization,
        current_person: current_person,
        current_type: current_type,
        current_id: current_id
      ).call
    end

    def initialize(teammate:, organization:, current_person:, current_type:, current_id: nil)
      @teammate = teammate
      @organization = organization
      @current_person = current_person
      @current_type = current_type.to_sym
      @current_id = current_id
    end

    def call
      items = build_ordered_items
      current_index = items.index { |i| same_item?(i) }
      current_item = current_index ? items[current_index] : nil
      next_item = resolve_next_item(items, current_index)
      next_requires_check_in = items.any? { |i| i[:bucket] != BUCKET_GREEN }
      others = items.reject { |i| same_item?(i) }
      show_check_in_status_done =
        current_item.present? &&
          current_item[:bucket] == BUCKET_RED &&
          others.any? &&
          others.all? { |i| i[:bucket] == BUCKET_GREEN }

      next_url = next_item ? url_for_item(next_item) : nil

      {
        next_url: next_url,
        next_requires_check_in: next_requires_check_in,
        next_item: next_item,
        ordered_items: items,
        show_check_in_status_done: show_check_in_status_done
      }
    end

    private

    attr_reader :teammate, :organization, :current_person, :current_type, :current_id

    def same_item?(item)
      return false unless item[:type] == current_type

      if item[:type] == :position
        current_id.blank?
      else
        item[:id].to_i == current_id.to_i
      end
    end

    def employee?
      current_person&.id == teammate.person_id
    end

    def my_side_completed_at(check_in)
      return nil unless check_in

      employee? ? check_in.employee_completed_at : check_in.manager_completed_at
    end

    # Map EH Required Clarity status → next-item urgency bucket.
    def bucket_for_finalized_at(finalized_at)
      status = EngagementHealth::Thresholds.status_for_last_event(
        finalized_at,
        healthy_within: EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS,
        needs_attention_at: EngagementHealth::Thresholds::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS
      )
      case status
      when EngagementHealth::HEALTHY
        BUCKET_GREEN
      when EngagementHealth::WARNING
        BUCKET_YELLOW
      else
        BUCKET_RED
      end
    end

    def build_ordered_items
      aspirations = build_aspiration_items
      assignments = build_assignment_items
      position_item = build_position_item

      all = aspirations + assignments + (position_item ? [position_item] : [])
      sort_by_my_side_completion_then_type_and_name(all)
    end

    def build_aspiration_items
      Aspiration.within_hierarchy(organization).ordered.map do |aspiration|
        open_ci = AspirationCheckIn.where(company_teammate: teammate, aspiration: aspiration).open.first
        latest_finalized_at = AspirationCheckIn.latest_finalized_for(teammate, aspiration)&.official_check_in_completed_at
        {
          type: :aspiration,
          id: aspiration.id,
          name: aspiration.name,
          bucket: bucket_for_finalized_at(latest_finalized_at),
          bucket_activity_at: latest_finalized_at,
          required: true,
          my_side_completed_at: my_side_completed_at(open_ci)
        }
      end
    end

    def build_assignment_items
      active_tenures = teammate.assignment_tenures
        .active
        .joins(:assignment)
        .where(assignments: { company: organization.self_and_descendants })
        .includes(:assignment)
        .distinct

      active_assignments_by_id = active_tenures.index_by(&:assignment_id).transform_values(&:assignment)
      required_assignment_ids = required_position_assignment_ids
      required_assignments_by_id = if required_assignment_ids.any?
        Assignment.where(id: required_assignment_ids, company: organization.self_and_descendants).index_by(&:id)
      else
        {}
      end
      assignments_by_id = required_assignments_by_id.merge(active_assignments_by_id)

      assignments_by_id.values.map do |assignment|
        open_ci = AssignmentCheckIn.where(company_teammate: teammate, assignment: assignment).open.first
        latest_finalized_at = AssignmentCheckIn.latest_finalized_for(teammate, assignment)&.official_check_in_completed_at
        {
          type: :assignment,
          id: assignment.id,
          name: assignment.title,
          bucket: bucket_for_finalized_at(latest_finalized_at),
          bucket_activity_at: latest_finalized_at,
          required: true,
          my_side_completed_at: my_side_completed_at(open_ci)
        }
      end
    end

    def build_position_item
      employment = teammate.employment_tenures.active.first
      return nil unless employment&.position

      open_ci = PositionCheckIn.where(company_teammate: teammate).open.first
      latest_finalized_at = PositionCheckIn.latest_finalized_for(teammate)&.official_check_in_completed_at
      name = employment.position.title&.external_title.presence || "Position"
      {
        type: :position,
        id: employment.position.id,
        name: name,
        bucket: bucket_for_finalized_at(latest_finalized_at),
        bucket_activity_at: latest_finalized_at,
        required: true,
        my_side_completed_at: my_side_completed_at(open_ci)
      }
    end

    def sort_by_my_side_completion_then_type_and_name(items)
      type_order = { aspiration: 0, assignment: 1, position: 2 }
      items.sort_by do |i|
        completed_at = i[:my_side_completed_at]
        type_rank = type_order[i[:type]] || 99
        name_key = i[:name].to_s.downcase

        if completed_at.present?
          [1, completed_at, type_rank, name_key]
        else
          [
            0,
            bucket_urgency_rank(i[:bucket]),
            type_rank,
            i[:bucket_activity_at] || Time.zone.at(0),
            name_key
          ]
        end
      end
    end

    def required_position_assignment_ids
      active_position = teammate.employment_tenures.active.where(company: organization).first&.position
      return [] unless active_position

      active_position.required_assignments.pluck(:assignment_id)
    end

    # Items are sorted red → yellow → green. Prefer any other item with a more
    # urgent bucket first; otherwise advance circularly in the list.
    def resolve_next_item(items, current_index)
      return items.first if items.blank? || current_index.nil?

      current_bucket = items[current_index][:bucket]
      current_rank = bucket_urgency_rank(current_bucket)

      more_urgent = items.find do |i|
        !same_item?(i) && bucket_urgency_rank(i[:bucket]) < current_rank
      end
      return more_urgent if more_urgent

      n = items.size
      return items.first if n <= 1

      (1...n).each do |step|
        idx = (current_index + step) % n
        candidate = items[idx]
        return candidate unless same_item?(candidate)
      end

      items[(current_index + 1) % n]
    end

    def bucket_urgency_rank(bucket)
      case bucket
      when BUCKET_RED then 0
      when BUCKET_YELLOW then 1
      when BUCKET_GREEN then 2
      else 3
      end
    end

    def url_for_item(item)
      case item[:type]
      when :aspiration
        Rails.application.routes.url_helpers.organization_teammate_aspiration_path(organization, teammate, item[:id])
      when :assignment
        Rails.application.routes.url_helpers.organization_teammate_assignment_path(organization, teammate, item[:id])
      when :position
        Rails.application.routes.url_helpers.position_check_in_organization_teammate_path(organization, teammate)
      else
        nil
      end
    end
  end
end
