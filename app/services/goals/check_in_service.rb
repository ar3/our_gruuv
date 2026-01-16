module Goals
  class CheckInService
    def self.call(...) = new(...).call

    def initialize(goal:, current_person:, confidence_percentage: nil, confidence_reason: nil, most_likely_target_date: nil, week_start: nil)
      @goal = goal
      @current_person = current_person
      @confidence_percentage = confidence_percentage.present? ? confidence_percentage.to_i : nil
      @confidence_reason = confidence_reason&.strip.presence
      @most_likely_target_date_param = most_likely_target_date
      @week_start = week_start || Date.current.beginning_of_week(:monday)
    end

    def call
      # Set PaperTrail whodunnit for version tracking
      PaperTrail.request.whodunnit = @current_person.id.to_s

      # Parse target date if provided
      most_likely_target_date = nil
      if @most_likely_target_date_param.present?
        most_likely_target_date = Date.parse(@most_likely_target_date_param.to_s)
      end

      # Handle target date update if provided
      target_date_updated = false
      if most_likely_target_date.present?
        # Ensure earliest date is not after the new target date if earliest is set
        if @goal.earliest_target_date.present? && @goal.earliest_target_date > most_likely_target_date
          @goal.earliest_target_date = most_likely_target_date
        end

        # Ensure latest date is at least one day after the new target date if latest is set
        if @goal.latest_target_date.present? && most_likely_target_date >= @goal.latest_target_date
          @goal.latest_target_date = most_likely_target_date + 1.day
        end

        @goal.most_likely_target_date = most_likely_target_date
        target_date_updated = true
      end

      # If only reason is provided without confidence, use last check-in's confidence or default to 5%
      if @confidence_percentage.nil? && @confidence_reason.present?
        # Get the most recent check-in, excluding the current week (if it exists)
        last_check_in = @goal.goal_check_ins
          .where.not(check_in_week_start: @week_start)
          .recent
          .first
        # Use last check-in's confidence if it exists and is not nil, otherwise default to 5%
        @confidence_percentage = (last_check_in&.confidence_percentage || 5)
      end

      # Find or initialize check-in for the week
      check_in = GoalCheckIn.find_or_initialize_by(
        goal: @goal,
        check_in_week_start: @week_start
      )

      check_in.assign_attributes(
        confidence_percentage: @confidence_percentage,
        confidence_reason: @confidence_reason,
        confidence_reporter: @current_person
      )

      # Save both check-in and goal (if target date was updated)
      success = false
      if target_date_updated
        Goal.transaction do
          success = check_in.save && @goal.save
          unless success
            raise ActiveRecord::Rollback
          end
        end
      else
        success = check_in.save
      end

      unless success
        errors = check_in.errors.full_messages
        errors += @goal.errors.full_messages if target_date_updated && @goal.errors.any?
        return Result.err(errors.join(', '))
      end

      # Start goal if it hasn't been started yet
      if @goal.started_at.nil?
        @goal.update(started_at: Time.current)
      end

      # Auto-complete goal if confidence is 0% or 100%
      if @confidence_percentage.present? && (@confidence_percentage == 0 || @confidence_percentage == 100) && @goal.completed_at.nil?
        @goal.update(completed_at: Time.current)
      end

      # Create observable moment if confidence changed significantly
      ObservableMoments::CreateGoalCheckInMomentService.call(
        goal_check_in: check_in,
        created_by: @current_person
      )

      Result.ok(
        check_in: check_in,
        goal: @goal,
        target_date_updated: target_date_updated
      )
    rescue Date::Error => e
      Result.err("Invalid date format: #{e.message}")
    rescue => e
      Result.err("Failed to save check-in: #{e.message}")
    end
  end
end
