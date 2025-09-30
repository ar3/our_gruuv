require 'set'

class Organizations::AssignmentTenuresController < ApplicationController
  layout 'authenticated-v2-0'
  before_action :require_authentication
  before_action :set_organization
  before_action :set_person
  after_action :verify_authorized
  before_action :log_request_info

  def show
    authorize @person, :manager?, policy_class: PersonPolicy
    load_assignments_and_check_ins
  end

  def update
    authorize @person, :manager?, policy_class: PersonPolicy
    
    # Capture security information
    request_info = {
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      session_id: session.id,
      request_id: SecureRandom.uuid,
      timestamp: Time.current
    }
    
    # Build MaapSnapshot with proposed changes from form parameters
    maap_snapshot = MaapSnapshot.build_for_employee_with_changes(
      employee: @person,
      created_by: current_person,
      change_type: 'assignment_management',
      reason: params[:reason] || 'Assignment updates',
      request_info: request_info,
      form_params: params
    )
    
    if maap_snapshot.save
      redirect_to execute_changes_organization_person_path(@organization, @person, maap_snapshot), 
                  notice: "Changes queued for processing. Review and execute below. #{@person&.full_name} - #{maap_snapshot&.id}"
    else
      Rails.logger.error "MaapSnapshot save failed: #{maap_snapshot.errors.full_messages}"
      redirect_to organization_assignment_tenure_path(@organization, @person), 
                  alert: 'Failed to create change record. Please try again.'
    end
  end

  def changes_confirmation
    authorize @person, :manager?, policy_class: PersonPolicy
    load_assignments_and_check_ins
  end


  def choose_assignments
    authorize @person, :manager?, policy_class: PersonPolicy
    
    @person_position = load_person_current_position
    @current_employment = @person.employment_tenures.active.first
    
    if @current_employment.nil?
      # No active employment tenure - redirect to create one
      redirect_to new_person_employment_tenure_path(@person), 
                  alert: 'Please create an employment tenure first before managing assignments.'
      return
    end
    
    @available_assignments = load_available_assignments_for_company(@current_employment.company)
    @current_assignments = load_person_assignments
    @assignments_by_organization = group_assignments_by_organization
  end

  def update_assignments
    authorize @person, :manager?, policy_class: PersonPolicy
    
    if update_person_assignments
      redirect_to organization_assignment_tenure_path(@organization, @person), notice: 'Assignments updated successfully.'
    else
      @available_assignments = load_available_assignments
      render :choose_assignments, status: :unprocessable_entity
    end
  end

  private

  def normalize_value(value)
    case value
    when nil, ''
      nil
    when String
      value.strip.empty? ? nil : value.strip
    else
      value
    end
  end

  def calculate_effective_tenure_value(assignment_id, db_value)
    # If we have a db_value, use it
    return db_value if db_value.present?
    
    # Otherwise, calculate from the assignment's default energy
    assignment = Assignment.find(assignment_id)
    assignment.default_energy_percentage
  end

  def set_organization
    @organization = Organization.find(params[:organization_id])
  end

  def set_person
    @person = Person.find(params[:id])
  end

  def load_assignments_and_check_ins
    # Get current employment for position info
    @current_employment = @person.employment_tenures.active.first
    
    # Get all assignments for this person (both active and inactive)
    all_assignments = load_person_assignments
    
    # Filter assignments to only show those within the current organization's company
    @assignments = all_assignments.select { |assignment| assignment.company == @organization }
    
    # For each assignment, get the active tenure and open check-in
    @assignment_data = @assignments.map do |assignment|
      # Get active tenure specifically (for energy values)
      active_tenure = @person.assignment_tenures.where(assignment: assignment).active.first
      
      # Get most recent tenure (for general info like start date)
      most_recent_tenure = AssignmentTenure.most_recent_for(@person, assignment)
      
      open_check_in = AssignmentCheckIn.where(person: @person, assignment: assignment).open.first
      
      # If there's a completed check-in, treat it as empty for the assignment tenures page
      # This prevents users from updating completed check-ins
      effective_check_in = if open_check_in&.official_check_in_completed_at.present?
        nil  # Treat completed check-ins as empty
      else
        open_check_in
      end
      
      {
        assignment: assignment,
        tenure: active_tenure,  # Use active tenure for energy values
        most_recent_tenure: most_recent_tenure,  # Keep most recent for other info
        open_check_in: effective_check_in,
        original_check_in: open_check_in  # Keep original for debugging/tooltip
      }
    end.sort_by { |data| -(data[:tenure]&.anticipated_energy_percentage || 0) }
  end

  def load_person_assignments
    # Get assignments that the person actually has tenures for
    @person.assignment_tenures.includes(:assignment).map(&:assignment).uniq
  end

  def load_available_assignments
    # Get all assignments that could be added to this person
    current_assignments = load_person_assignments
    all_assignments = Assignment.includes(:company).order(:title)
    
    all_assignments.reject { |assignment| current_assignments.include?(assignment) }
  end

  def load_available_assignments_for_company(company)
    # Get assignments for this company that the person doesn't already have
    current_assignments = load_person_assignments
    company_assignments = company.assignments.includes(:assignment_tenures).order(:title)
    
    company_assignments.reject { |assignment| current_assignments.include?(assignment) }
  end

  def group_assignments_by_organization
    # Group available assignments by their organization
    @available_assignments.group_by(&:company)
  end

  def update_person_assignments
    return false unless params[:selected_assignments].present?
    
    selected_assignment_ids = params[:selected_assignments].map(&:to_i)
    
    # Create new assignment tenures for selected assignments
    selected_assignment_ids.each do |assignment_id|
      assignment = Assignment.find(assignment_id)
      
      # Check if person already has an active tenure for this assignment
      existing_tenure = @person.assignment_tenures.where(assignment: assignment).active.first
      
      if existing_tenure.nil?
        # Create new tenure
        @person.assignment_tenures.create!(
          assignment: assignment,
          started_at: Date.current,
          anticipated_energy_percentage: assignment.default_energy_percentage
        )
      end
    end
    
    true
  rescue => e
    Rails.logger.error "Error updating assignments: #{e.message}"
    false
  end

  def load_person_current_position
    # Get the person's current position from their active employment
    @current_employment = @person.employment_tenures.active.first
    @current_employment&.position
  end

  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access assignment management.'
    end
  end

  def log_request_info
    Rails.logger.info "=== ASSIGNMENT TENURES REQUEST ==="
    Rails.logger.info "Action: #{action_name}"
    Rails.logger.info "Method: #{request.method}"
    Rails.logger.info "Params: #{params.inspect}"
    Rails.logger.info "Current person: #{current_person.inspect}"
    Rails.logger.info "=== END REQUEST INFO ==="
  end
end
