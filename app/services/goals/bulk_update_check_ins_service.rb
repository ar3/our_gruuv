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

      # Check authorization: teammate-owned => creator or owner only; team/dept/company => can see can check-in
      teammate = current_person.teammates.find_by(organization: organization)
      unless teammate
        return add_error(goal_id, "You don't have permission to update check-ins for this goal")
      end
      pundit_user = OpenStruct.new(user: teammate, impersonating_teammate: nil)
      check_in_record = GoalCheckIn.new(goal: goal)
      unless GoalCheckInPolicy.new(pundit_user, check_in_record).create?
        return add_error(goal_id, "You don't have permission to update check-ins for this goal")
      end

      # Parse and normalize values
      confidence_percentage = check_in_data[:confidence_percentage].present? ? check_in_data[:confidence_percentage].to_i : nil
      confidence_reason = check_in_data[:confidence_reason]&.strip.presence
      
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

      # Check authorization for goal update if target date is being updated
      if check_in_data[:most_likely_target_date].present?
        teammate = current_person.teammates.find_by(organization: organization)
        unless teammate
          return add_error(goal_id, "You don't have permission to update this goal")
        end
        
        pundit_user = OpenStruct.new(user: teammate, impersonating_teammate: nil)
        policy = GoalPolicy.new(pundit_user, goal)
        unless policy.update?
          return add_error(goal_id, "You don't have permission to update this goal")
        end
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

      # Use the CheckInService to handle the check-in
      result = CheckInService.call(
        goal: goal,
        current_person: current_person,
        confidence_percentage: confidence_percentage,
        confidence_reason: confidence_reason,
        most_likely_target_date: check_in_data[:most_likely_target_date],
        week_start: week_start
      )

      if result.ok?
        @success_count += 1
      else
        @failure_count += 1
        add_error(goal_id, result.error)
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

