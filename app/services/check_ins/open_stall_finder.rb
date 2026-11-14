# frozen_string_literal: true

module CheckIns
  # Finds the worst timed mid-flow stall among open required-clarity check-ins.
  # Used by OG Academy Check-in captions (and later surfaces).
  #
  # Severity then age: any stale joint review outranks any one-sided stall;
  # within a tier, the longest wait wins.
  class OpenStallFinder
    ASYMMETRIC_STALL_DAYS = 5
    STALE_REVIEW_DAYS = 3

    CHECK_IN_MODELS = {
      "Assignment" => AssignmentCheckIn,
      "Position" => PositionCheckIn,
      "Aspiration" => AspirationCheckIn
    }.freeze

    KIND_SEVERITY = {
      stale_review: 0,
      asymmetric: 1
    }.freeze

    Stall = Struct.new(
      :kind,
      :days,
      :waiting_on,
      :object_name,
      :entity_type,
      :item,
      :check_in,
      keyword_init: true
    )

    def self.worst_for(records, reference_time: Time.current)
      new(records, reference_time: reference_time).worst
    end

    def initialize(records, reference_time: Time.current)
      @items = EngagementHealth::ClarityMetrics.clarity_items(records)
      @reference_time = reference_time
    end

    def worst
      stalls = candidate_stalls
      return nil if stalls.empty?

      stalls.min_by do |stall|
        [
          KIND_SEVERITY.fetch(stall.kind, 99),
          -stall.days,
          stall.entity_type.to_s,
          stall.object_name.to_s.downcase
        ]
      end
    end

    private

    attr_reader :items, :reference_time

    def candidate_stalls
      open_check_ins = load_open_check_ins
      items.filter_map do |item|
        inputs = item.inputs || {}
        next unless ActiveModel::Type::Boolean.new.cast(inputs["open_check_in_present"])

        check_in_id = inputs["open_check_in_id"]
        next if check_in_id.blank?

        check_in = open_check_ins[check_in_key(item.entity_type, check_in_id)]
        next if check_in.blank?

        stall_for(item, check_in)
      end
    end

    def stall_for(item, check_in)
      employee_at = check_in.employee_completed_at
      manager_at = check_in.manager_completed_at
      employee_done = employee_at.present?
      manager_done = manager_at.present?

      if employee_done && manager_done
        ready_at = [employee_at, manager_at].max
        days = days_since(ready_at)
        return nil if days < STALE_REVIEW_DAYS

        return build_stall(
          kind: :stale_review,
          days: days,
          waiting_on: :review,
          item: item,
          check_in: check_in
        )
      end

      if employee_done ^ manager_done
        completed_at = employee_done ? employee_at : manager_at
        days = days_since(completed_at)
        return nil if days < ASYMMETRIC_STALL_DAYS

        return build_stall(
          kind: :asymmetric,
          days: days,
          waiting_on: employee_done ? :manager : :employee,
          item: item,
          check_in: check_in
        )
      end

      nil
    end

    def build_stall(kind:, days:, waiting_on:, item:, check_in:)
      Stall.new(
        kind: kind,
        days: days,
        waiting_on: waiting_on,
        object_name: (item.inputs || {})["name"].to_s,
        entity_type: item.entity_type,
        item: item,
        check_in: check_in
      )
    end

    def load_open_check_ins
      ids_by_type = Hash.new { |h, k| h[k] = [] }
      items.each do |item|
        inputs = item.inputs || {}
        next unless ActiveModel::Type::Boolean.new.cast(inputs["open_check_in_present"])

        id = inputs["open_check_in_id"]
        next if id.blank?

        ids_by_type[item.entity_type.to_s] << id
      end

      result = {}
      ids_by_type.each do |entity_type, ids|
        model = CHECK_IN_MODELS[entity_type]
        next unless model

        model.where(id: ids.uniq, official_check_in_completed_at: nil).find_each do |check_in|
          result[check_in_key(entity_type, check_in.id)] = check_in
        end
      end
      result
    end

    def check_in_key(entity_type, id)
      "#{entity_type}:#{id}"
    end

    def days_since(time)
      return 0 if time.blank?

      ((reference_time - time) / 1.day).floor
    end
  end
end
