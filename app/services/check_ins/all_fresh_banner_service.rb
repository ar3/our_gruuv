# frozen_string_literal: true

module CheckIns
  # Determines whether the unified check-in page should show the "all fresh" success banner.
  # Scope: required + active assignment check-ins, all company aspirations, position check-in.
  class AllFreshBannerService
    FRESH_DAYS = EngagementHealth::Thresholds::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS

    Result = Struct.new(
      :show_banner,
      :show_clarity_follow_up,
      :check_back_in_days,
      :organization_display_name,
      keyword_init: true
    )

    def self.call(teammate:, organization:, view_mode:, position_check_in:, aspiration_check_ins:, assignment_check_ins:)
      new(
        teammate: teammate,
        organization: organization,
        view_mode: view_mode,
        position_check_in: position_check_in,
        aspiration_check_ins: aspiration_check_ins,
        assignment_check_ins: assignment_check_ins
      ).call
    end

    def initialize(teammate:, organization:, view_mode:, position_check_in:, aspiration_check_ins:, assignment_check_ins:)
      @teammate = teammate
      @organization = organization
      @view_mode = view_mode
      @position_check_in = position_check_in
      @aspiration_check_ins = Array(aspiration_check_ins)
      @assignment_check_ins = Array(assignment_check_ins)
    end

    def call
      items = build_items
      return empty_result if items.empty?

      # Calendar-day window matches EngagementHealth Required Clarity Healthy threshold.
      freshness = items.map { |item| item_fresh?(item) }
      all_fresh = freshness.all?

      finalized_recent = items.map { |item| recent_finalized?(item) }
      all_finalized_recent = finalized_recent.all?

      finalized_timestamps = items.filter_map { |item| latest_finalized_timestamp(item) }
      earliest = finalized_timestamps.min

      check_back =
        if all_fresh && all_finalized_recent && earliest
          days_since = (Time.zone.today - earliest.to_date).to_i
          [0, FRESH_DAYS - days_since].max
        end

      Result.new(
        show_banner: all_fresh,
        show_clarity_follow_up: all_fresh && all_finalized_recent,
        check_back_in_days: check_back,
        organization_display_name: @organization.root_company&.name || @organization.name
      )
    end

    private

    def empty_result
      Result.new(
        show_banner: false,
        show_clarity_follow_up: false,
        check_back_in_days: nil,
        organization_display_name: @organization.root_company&.name || @organization.name
      )
    end

    def build_items
      list = []
      list.concat(@assignment_check_ins.map { |ci| { kind: :assignment, open: ci, assignment: ci.assignment } })
      list.concat(
        @aspiration_check_ins.map { |ci| { kind: :aspiration, open: ci, aspiration: ci.aspiration } }
      )
      if @position_check_in
        list << { kind: :position, open: @position_check_in }
      end
      list
    end

    def item_fresh?(item)
      recent_finalized?(item) || viewer_completed_side?(item[:open])
    end

    def recent_finalized?(item)
      ts = latest_finalized_timestamp(item)
      return false if ts.blank?

      (Time.zone.today - ts.to_date).to_i <= FRESH_DAYS
    end

    def latest_finalized_timestamp(item)
      case item[:kind]
      when :position
        PositionCheckIn.latest_finalized_for(@teammate)&.official_check_in_completed_at
      when :aspiration
        aspiration = item[:aspiration]
        return nil unless aspiration

        AspirationCheckIn.latest_finalized_for(@teammate, aspiration)&.official_check_in_completed_at
      when :assignment
        assignment = item[:assignment]
        return nil unless assignment

        AssignmentCheckIn.latest_finalized_for(@teammate, assignment)&.official_check_in_completed_at
      end
    end

    def viewer_completed_side?(open_check_in)
      return false unless open_check_in

      case @view_mode
      when :employee
        open_check_in.employee_completed?
      when :manager
        open_check_in.manager_completed?
      else
        false
      end
    end
  end
end
