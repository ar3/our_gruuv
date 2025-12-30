module Goals
  class BulkUpdateCheckInsService
    def self.call(...) = new(...).call

    def initialize(organization:, current_person:, goal_check_ins_params:, week_start:)
      @organization = organization
      @current_person = current_person
      @goal_check_ins_params = goal_check_ins_params || {}
      @week_start = week_start
      @success_count = 0
      @failure_count = 0
      @errors = []
    end

    def call
      @goal_check_ins_params.each do |goal_id, check_in_data|
        process_check_in(goal_id, check_in_data)
      end

      Result.ok(
        success_count: @success_count,
        failure_count: @failure_count,
        errors: @errors
      )
    end

    private

    attr_reader :organization, :current_person, :goal_check_ins_params, :week_start

    def process_check_in(goal_id, check_in_data)
      # Find goal without filtering by started_at - allow check-ins for any goal
      goal = Goal.where(company: organization, deleted_at: nil, completed_at: nil).find_by(id: goal_id)
      return add_error(goal_id, "Goal not found") unless goal

      # Skip completed goals - they should not have check-ins updated
      if goal.completed_at.present?
        return
      end

      # Check authorization - user must be able to view the goal
      unless goal.can_be_viewed_by?(current_person)
        return add_error(goal_id, "You don't have permission to update check-ins for this goal")
      end

      # Parse and normalize values
      confidence_percentage = check_in_data[:confidence_percentage].present? ? check_in_data[:confidence_percentage].to_i : nil
      confidence_reason = check_in_data[:confidence_reason]&.strip.presence
      
      # Handle target date update if provided
      target_date_updated = false
      if check_in_data[:most_likely_target_date].present?
        # Check authorization for goal update using Pundit
        teammate = current_person.teammates.find_by(organization: organization)
        unless teammate
          return add_error(goal_id, "You don't have permission to update this goal")
        end
        
        pundit_user = OpenStruct.new(user: teammate, impersonating_teammate: nil)
        policy = GoalPolicy.new(pundit_user, goal)
        unless policy.update?
          return add_error(goal_id, "You don't have permission to update this goal")
        end
        
        new_target_date = Date.parse(check_in_data[:most_likely_target_date])
        
        # Ensure earliest date is not after the new target date if earliest is set
        if goal.earliest_target_date.present? && goal.earliest_target_date > new_target_date
          goal.earliest_target_date = new_target_date
        end
        
        # Ensure latest date is at least one day after the new target date if latest is set
        if goal.latest_target_date.present? && new_target_date >= goal.latest_target_date
          goal.latest_target_date = new_target_date + 1.day
        end
        
        goal.most_likely_target_date = new_target_date
        target_date_updated = true
      end

      # If both fields are empty, delete existing check-in if it exists
      if confidence_percentage.nil? && confidence_reason.nil?
        existing_check_in = GoalCheckIn.find_by(
          goal: goal,
          check_in_week_start: week_start
        )
        
        if existing_check_in
          # Set PaperTrail whodunnit for version tracking
          PaperTrail.request.whodunnit = current_person.id.to_s
          existing_check_in.destroy
          @success_count += 1
        end
        return
      end

      # If only reason is provided without confidence, use last check-in's confidence or default to 5%
      if confidence_percentage.nil? && confidence_reason.present?
        # Get the most recent check-in, excluding the current week (if it exists)
        last_check_in = goal.goal_check_ins
          .where.not(check_in_week_start: week_start)
          .recent
          .first
        # Use last check-in's confidence if it exists and is not nil, otherwise default to 5%
        confidence_percentage = (last_check_in&.confidence_percentage || 5)
      end

      # Set PaperTrail whodunnit for version tracking
      PaperTrail.request.whodunnit = current_person.id.to_s

      # Find or initialize check-in for current week
      check_in = GoalCheckIn.find_or_initialize_by(
        goal: goal,
        check_in_week_start: week_start
      )

      # Update fields
      check_in.confidence_percentage = confidence_percentage
      check_in.confidence_reason = confidence_reason
      check_in.confidence_reporter = current_person

      # Save both check-in and goal (if target date was updated)
      success = true
      if target_date_updated
        Goal.transaction do
          success = check_in.save && goal.save
          unless success
            raise ActiveRecord::Rollback
          end
        end
      else
        success = check_in.save
      end

      if success
        # Auto-complete goal if confidence is 0% or 100%
        if confidence_percentage.present? && (confidence_percentage == 0 || confidence_percentage == 100) && goal.completed_at.nil?
          goal.update(completed_at: Time.current)
        end
        
        @success_count += 1
      else
        @failure_count += 1
        error_messages = []
        error_messages.concat(check_in.errors.full_messages) if check_in.errors.any?
        error_messages.concat(goal.errors.full_messages) if goal.errors.any?
        add_error(goal_id, error_messages.join(', '))
      end
    rescue => e
      @failure_count += 1
      add_error(goal_id, "Unexpected error: #{e.message}")
    end

    def add_error(goal_id, message)
      @errors << { goal_id: goal_id, message: message }
    end
  end
end

