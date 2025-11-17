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
      goal = Goal.active.find_by(id: goal_id, company: organization)
      return add_error(goal_id, "Goal not found") unless goal

      # Skip completed goals - they should not have check-ins updated
      if goal.completed_at.present?
        return
      end

      # Check authorization - user must be able to view the goal
      unless goal.can_be_viewed_by?(current_person)
        return add_error(goal_id, "You don't have permission to update check-ins for this goal")
      end

      confidence_percentage = check_in_data[:confidence_percentage]&.to_i
      confidence_reason = check_in_data[:confidence_reason]&.strip

      # Set PaperTrail whodunnit for version tracking
      PaperTrail.request.whodunnit = current_person.id.to_s

      # Find or initialize check-in for current week
      check_in = GoalCheckIn.find_or_initialize_by(
        goal: goal,
        check_in_week_start: week_start
      )

      check_in.assign_attributes(
        confidence_percentage: confidence_percentage,
        confidence_reason: confidence_reason,
        confidence_reporter: current_person
      )

      if check_in.save
        # Auto-complete goal if confidence is 0% or 100%
        if (confidence_percentage == 0 || confidence_percentage == 100) && goal.completed_at.nil?
          goal.update(completed_at: Time.current)
        end
        
        @success_count += 1
      else
        @failure_count += 1
        add_error(goal_id, check_in.errors.full_messages.join(', '))
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

