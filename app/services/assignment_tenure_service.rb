class AssignmentTenureService
  class TenureLifecycleError < StandardError; end

  def initialize(person:, assignment:, created_by:)
    @person = person
    @assignment = assignment
    @created_by = created_by
  end

  # Updates or creates assignment tenure based on energy changes
  # Handles the complete lifecycle: ending old tenures, creating new ones
  def update_tenure(anticipated_energy_percentage:, started_at:)
    @anticipated_energy_percentage = anticipated_energy_percentage.to_i
    
    begin
      @started_at = Date.parse(started_at.to_s)
    rescue Date::Error => e
      raise TenureLifecycleError, "Started at must be a valid date: #{e.message}"
    end

    validate_inputs!

    if @anticipated_energy_percentage == 0
      end_active_tenure
    else
      handle_energy_change
    end
  end

  private

  attr_reader :person, :assignment, :created_by, :anticipated_energy_percentage, :started_at

  def validate_inputs!
    raise TenureLifecycleError, "Person cannot be nil" unless person
    raise TenureLifecycleError, "Assignment cannot be nil" unless assignment
    raise TenureLifecycleError, "Anticipated energy must be between 0 and 100" unless (0..100).include?(@anticipated_energy_percentage)
    raise TenureLifecycleError, "Started at must be a valid date" unless @started_at.is_a?(Date)
  end

  def active_tenure
    @active_tenure ||= person.assignment_tenures
                            .where(assignment: assignment)
                            .active
                            .first
  end

  def end_active_tenure
    return unless active_tenure

    # End the tenure on the same day as the new start date
    # This allows same-day transitions
    end_date = @started_at
    
    active_tenure.update!(ended_at: end_date)
  end

  def handle_energy_change
    if active_tenure && active_tenure.anticipated_energy_percentage != @anticipated_energy_percentage
      # Energy changed - end current tenure and create new one
      end_current_tenure_and_create_new
    elsif !active_tenure
      # No active tenure - create new one
      create_new_tenure
    end
    # If active_tenure exists and energy is the same, no changes needed
  end

  def end_current_tenure_and_create_new
    # End current tenure on the same day as the new start date
    # This allows same-day transitions
    end_date = @started_at
    
    active_tenure.update!(ended_at: end_date)
    
    # Clear the cached active_tenure so it's not found on next query
    @active_tenure = nil

    create_new_tenure
  end

  def create_new_tenure
    AssignmentTenure.create!(
      person: person,
      assignment: assignment,
      anticipated_energy_percentage: @anticipated_energy_percentage,
      started_at: @started_at
    )
  end
end
