# frozen_string_literal: true

module Goals
  # Update sheet fields for one goal. Confidence/reason go through CheckInService
  # (which starts the goal). Other fields go through GoalForm. PaperTrail logs both.
  class BulkEditUpdate
    Result = Struct.new(:ok?, :goal, :errors, :saved_at, keyword_init: true)

    def self.call(...) = new(...).call

    def initialize(goal:, current_person:, current_teammate:, attrs:)
      @goal = goal
      @current_person = current_person
      @current_teammate = current_teammate
      @attrs = attrs.to_h.with_indifferent_access
    end

    def call
      PaperTrail.request.whodunnit = @current_teammate&.id&.to_s

      goal_errors = update_goal_fields
      return failure(goal_errors) if goal_errors.any?

      check_in_errors = update_check_in_fields
      return failure(check_in_errors) if check_in_errors.any?

      @goal.reload
      EngagementHealth.schedule_refresh_for_goal(@goal)
      Result.new(ok?: true, goal: @goal, errors: [], saved_at: Time.current.iso8601)
    end

    private

    def update_goal_fields
      form_attrs = {}
      form_attrs[:title] = @attrs[:title] if @attrs.key?(:title)
      form_attrs[:description] = @attrs[:description] if @attrs.key?(:description)
      form_attrs[:goal_type] = @attrs[:goal_type] if @attrs.key?(:goal_type)
      form_attrs[:privacy_level] = @attrs[:privacy_level] if @attrs.key?(:privacy_level)
      if @attrs.key?(:most_likely_target_date)
        form_attrs[:most_likely_target_date] = parse_sheet_date(@attrs[:most_likely_target_date])
      end
      form_attrs[:owner_id] = @attrs[:owner_id] if @attrs.key?(:owner_id) && @attrs[:owner_id].present?

      return [] if form_attrs.empty?

      # Preserve required fields GoalForm validates on every save.
      form_attrs[:privacy_level] ||= @goal.privacy_level
      form_attrs[:edit_check_in_permission] ||= @goal.edit_check_in_permission
      form_attrs[:title] ||= @goal.title
      form_attrs[:goal_type] ||= @goal.goal_type
      unless form_attrs.key?(:owner_id)
        owner_type = @goal.owner_type == "Organization" ? "Company" : @goal.owner_type
        form_attrs[:owner_id] = "#{owner_type}_#{@goal.owner_id}"
      end

      form = GoalForm.new(@goal)
      form.current_person = @current_person
      form.current_teammate = @current_teammate
      return form.errors.full_messages unless form.validate(form_attrs) && form.save

      []
    end

    def update_check_in_fields
      has_confidence = @attrs.key?(:confidence_percentage)
      has_reason = @attrs.key?(:confidence_reason)
      return [] unless has_confidence || has_reason

      raw_percentage = @attrs[:confidence_percentage]
      percentage = if raw_percentage.nil? || raw_percentage.to_s.strip.empty?
        nil
      else
        raw_percentage.to_s.to_i # "100_late" => 100, "0" => 0
      end
      reason = @attrs[:confidence_reason].to_s.strip.presence

      # Clearing both is a no-op on the sheet (do not destroy check-ins here).
      return [] if percentage.nil? && reason.blank?

      week_start = Date.current.beginning_of_week(:monday)
      current = @goal.goal_check_ins.find_by(check_in_week_start: week_start)
      if current && current.confidence_percentage == percentage && current.confidence_reason.to_s.strip.presence == reason
        return []
      end

      result = Goals::CheckInService.call(
        goal: @goal,
        current_person: @current_person,
        current_company_teammate: @current_teammate,
        confidence_percentage: percentage,
        confidence_reason: reason
      )
      return [] if result.ok?

      Array(result.error)
    end

    def parse_sheet_date(value)
      return nil if value.blank?
      return value if value.is_a?(Date)
      return value.to_date if value.respond_to?(:to_date) && !value.is_a?(String)

      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      value
    end

    def failure(errors)
      Result.new(ok?: false, goal: @goal, errors: Array(errors), saved_at: nil)
    end
  end
end
