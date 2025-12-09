class CheckInCompletionService
  def self.complete_employee_side!(check_in)
    new(check_in).complete_employee_side!
  end

  def self.complete_manager_side!(check_in, completed_by:)
    new(check_in).complete_manager_side!(completed_by: completed_by)
  end

  def initialize(check_in)
    @check_in = check_in
    @was_ready_before = check_in.ready_for_finalization?
    @employee_completed_before = check_in.employee_completed?
    @manager_completed_before = check_in.manager_completed?
    @completion_detected = false
    @completion_state = nil
  end

  def complete_employee_side!
    @check_in.complete_employee_side!
    detect_completion_state
  end

  def complete_manager_side!(completed_by:)
    @check_in.complete_manager_side!(completed_by: completed_by)
    detect_completion_state
  end

  def completion_detected?
    @completion_detected || false
  end

  def completion_state
    @completion_state
  end

  private

  def detect_completion_state
    @check_in.reload
    employee_completed_now = @check_in.employee_completed?
    manager_completed_now = @check_in.manager_completed?

    # Detect if a completion happened (either side just completed)
    employee_just_completed = !@employee_completed_before && employee_completed_now
    manager_just_completed = !@manager_completed_before && manager_completed_now

    if employee_just_completed || manager_just_completed
      @completion_detected = true

      # Update the "before" state for subsequent calls
      @employee_completed_before = employee_completed_now
      @manager_completed_before = manager_completed_now

      # Determine the state after this completion
      if employee_completed_now && manager_completed_now
        @completion_state = :both_complete
      elsif employee_completed_now
        @completion_state = :employee_only
      elsif manager_completed_now
        @completion_state = :manager_only
      else
        @completion_state = nil
      end
    end
  end
end

