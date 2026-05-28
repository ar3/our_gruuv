# frozen_string_literal: true

module CheckIns
  # Returns the next single-item check-in target (aspiration, assignment, or position)
  # and whether the "Save and move to next" button should be enabled.
  # Bucket thresholds match CheckInBehavior#clarity_level (crystal clear / clear / blurred+obscured)
  # via CheckInBehavior.recency_tricolor_bucket. When all items are green (crystal-clear window),
  # next_requires_check_in is false.
  class SingleItemCheckInNextItemService
    BUCKET_RED = :red    # blurred + obscured vs clarity, or no activity
    BUCKET_YELLOW = :yellow # clear window
    BUCKET_GREEN = :green   # crystal_clear window

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

    def last_activity_time(check_in)
      return nil unless check_in
      times = [check_in.official_check_in_completed_at]
      times << check_in.employee_completed_at if employee?
      times << check_in.manager_completed_at unless employee?
      times.compact.max
    end

    def bucket_for(last_activity)
      case CheckInBehavior.recency_tricolor_bucket(last_activity)
      when :green
        BUCKET_GREEN
      when :blue
        BUCKET_YELLOW
      when :yellow
        BUCKET_RED
      else
        BUCKET_RED
      end
    end

    def build_ordered_items
      aspirations = build_aspiration_items
      assignments = build_assignment_items
      position_item = build_position_item

      all = aspirations + assignments + (position_item ? [position_item] : [])
      sort_by_bucket_and_type(all)
    end

    def build_aspiration_items
      Aspiration.within_hierarchy(organization).ordered.map do |aspiration|
        closed = AspirationCheckIn.where(company_teammate: teammate, aspiration: aspiration).closed
          .order(official_check_in_completed_at: :desc).first
        open_ci = AspirationCheckIn.where(company_teammate: teammate, aspiration: aspiration).open.first
        check_in = closed || open_ci
        last_activity = last_activity_time(check_in)
        {
          type: :aspiration,
          id: aspiration.id,
          name: aspiration.name,
          bucket: bucket_for(last_activity),
          required: false
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
        closed = AssignmentCheckIn.where(company_teammate: teammate, assignment: assignment).closed
          .order(official_check_in_completed_at: :desc).first
        open_ci = AssignmentCheckIn.where(company_teammate: teammate, assignment: assignment).open.first
        check_in = closed || open_ci
        last_activity = last_activity_time(check_in)
        {
          type: :assignment,
          id: assignment.id,
          name: assignment.title,
          bucket: bucket_for(last_activity),
          required: required_assignment_ids.include?(assignment.id) || active_assignments_by_id.key?(assignment.id)
        }
      end
    end

    def build_position_item
      employment = teammate.employment_tenures.active.first
      return nil unless employment&.position

      closed = PositionCheckIn.where(company_teammate: teammate).closed
        .order(official_check_in_completed_at: :desc).first
      open_ci = PositionCheckIn.where(company_teammate: teammate).open.first
      check_in = closed || open_ci
      last_activity = last_activity_time(check_in)
      name = employment.position.title&.external_title.presence || "Position"
      {
        type: :position,
        id: nil,
        name: name,
        bucket: bucket_for(last_activity),
        required: true
      }
    end

    def sort_by_bucket_and_type(items)
      required_order = ->(item) { item[:required] ? 0 : 1 }
      order = { BUCKET_RED => 0, BUCKET_YELLOW => 1, BUCKET_GREEN => 2 }
      type_order = { aspiration: 0, assignment: 1, position: 2 }
      items.sort_by { |i| [required_order.call(i), order[i[:bucket]], type_order[i[:type]] || 99, i[:id].to_i] }
    end

    def required_position_assignment_ids
      active_position = teammate.employment_tenures.active.where(company: organization).first&.position
      return [] unless active_position

      active_position.required_assignments.pluck(:assignment_id)
    end

    # Items are sorted red → yellow → green. Simple (index + 1) % n skips items that sort
    # *before* the current row (e.g. yellow assignment while on green assignment). Prefer any
    # other item with a more urgent bucket first; otherwise advance circularly in the list.
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
