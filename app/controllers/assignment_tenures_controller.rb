class AssignmentTenuresController < ApplicationController
  before_action :require_authentication
  before_action :set_person
  after_action :verify_authorized

  def show
    authorize @person, policy_class: PersonPolicy
    load_assignments_and_check_ins
  end

  def update
    authorize @person, policy_class: PersonPolicy
    
    if update_assignments_and_check_ins
      redirect_to person_assignment_tenures_path(@person), notice: 'Assignments updated successfully.'
    else
      load_assignments_and_check_ins
      render :show, status: :unprocessable_entity
    end
  end

  def choose_assignments
    authorize @person, policy_class: PersonPolicy
    @available_assignments = load_available_assignments
  end

  def update_assignments
    authorize @person, policy_class: PersonPolicy
    
    if update_person_assignments
      redirect_to person_assignment_tenures_path(@person), notice: 'Assignments updated successfully.'
    else
      @available_assignments = load_available_assignments
      render :choose_assignments, status: :unprocessable_entity
    end
  end

  private

  def set_person
    @person = Person.find(params[:person_id])
  end

  def load_assignments_and_check_ins
    # Get current employment for position info
    @current_employment = @person.employment_tenures.active.first
    
    # Get all assignments for this person (both active and inactive)
    @assignments = load_person_assignments
    
    # For each assignment, get the current tenure and open check-in
    @assignment_data = @assignments.map do |assignment|
      tenure = AssignmentTenure.most_recent_for(@person, assignment)
      open_check_in = AssignmentCheckIn.where(person: @person, assignment: assignment).open.first
      
      {
        assignment: assignment,
        tenure: tenure,
        open_check_in: open_check_in
      }
    end
  end

  def load_person_assignments
    # Get assignments from current employment tenure
    current_employment = @person.employment_tenures.active.first
    return [] unless current_employment
    
    # Get required assignments from position assignments
    position_assignments = current_employment.position.position_assignments.includes(:assignment)
    assignments = position_assignments.map(&:assignment)
    
    # Also get any existing assignment tenures for this person
    existing_tenures = @person.assignment_tenures.includes(:assignment)
    existing_assignments = existing_tenures.map(&:assignment)
    
    # Combine and deduplicate
    (assignments + existing_assignments).uniq
  end

  def load_available_assignments
    # Get all assignments that could be added to this person
    current_assignments = load_person_assignments
    all_assignments = Assignment.includes(:company).order(:title)
    
    all_assignments.reject { |assignment| current_assignments.include?(assignment) }
  end

  def update_assignments_and_check_ins
    ActiveRecord::Base.transaction do
      # Process each assignment's tenure and check-in data
      @assignment_data.each do |data|
        assignment = data[:assignment]
        tenure = data[:tenure]
        open_check_in = data[:open_check_in]
        
        # Update or create assignment tenure
        if tenure_params_present?(assignment.id)
          update_or_create_tenure(assignment, tenure)
        end
        
        # Update or create check-in
        if check_in_params_present?(open_check_in&.id)
          update_or_create_check_in(open_check_in, assignment)
        end
      end
      
      true
    rescue => e
      Rails.logger.error "Error updating assignments: #{e.message}"
      false
    end
  end

  def update_person_assignments
    selected_assignment_ids = params[:assignments] || []
    
    ActiveRecord::Base.transaction do
      selected_assignment_ids.each do |assignment_id|
        assignment = Assignment.find(assignment_id)
        
        # Create assignment tenure if it doesn't exist
        unless @person.assignment_tenures.exists?(assignment: assignment)
          @person.assignment_tenures.create!(
            assignment: assignment,
            started_at: Date.current,
            anticipated_energy_percentage: 5 # Default energy
          )
        end
      end
      
      true
    rescue => e
      Rails.logger.error "Error updating person assignments: #{e.message}"
      false
    end
  end

  private

  def tenure_params_present?(assignment_id)
    params["tenure_#{assignment_id}_anticipated_energy"].present?
  end

  def check_in_params_present?(check_in_id)
    return false unless check_in_id
    
    params["check_in_#{check_in_id}_actual_energy"].present? ||
    params["check_in_#{check_in_id}_employee_rating"].present? ||
    params["check_in_#{check_in_id}_personal_alignment"].present? ||
    params["check_in_#{check_in_id}_employee_private_notes"].present?
  end

  def update_or_create_tenure(assignment, existing_tenure)
    # If energy percentage changed, end current tenure and create new one
    new_energy = params["tenure_#{assignment.id}_anticipated_energy"].to_i
    
    if existing_tenure && existing_tenure.anticipated_energy_percentage != new_energy
      # End current tenure and start new one today
      existing_tenure.update!(ended_at: Date.current - 1.day)
      existing_tenure = nil
    end
    
    # Create new tenure if needed
    unless existing_tenure
      @person.assignment_tenures.create!(
        assignment: assignment,
        started_at: Date.current,
        anticipated_energy_percentage: new_energy
      )
    end
  end

  def update_or_create_check_in(existing_check_in, assignment)
    # Find or create open check-in
    if existing_check_in&.open?
      # Update existing open check-in
      existing_check_in.update!(
        actual_energy_percentage: params["check_in_#{existing_check_in.id}_actual_energy"].to_i,
        employee_rating: params["check_in_#{existing_check_in.id}_employee_rating"],
        employee_personal_alignment: params["check_in_#{existing_check_in.id}_personal_alignment"],
        employee_private_notes: params["check_in_#{existing_check_in.id}_employee_private_notes"]
      )
    else
      # Create new check-in
      tenure = AssignmentTenure.most_recent_for(@person, assignment)
      return unless tenure
      
      tenure.assignment_check_ins.create!(
        check_in_started_on: Date.current,
        actual_energy_percentage: params["check_in_#{existing_check_in&.id}_actual_energy"]&.to_i,
        employee_rating: params["check_in_#{existing_check_in&.id}_employee_rating"],
        employee_personal_alignment: params["check_in_#{existing_check_in&.id}_personal_alignment"],
        employee_private_notes: params["check_in_#{existing_check_in&.id}_employee_private_notes"]
      )
    end
  end

  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access assignment management.'
    end
  end
end
