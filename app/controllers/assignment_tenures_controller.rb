require 'set'

class AssignmentTenuresController < ApplicationController
  layout 'authenticated-v2-0'
  before_action :require_authentication
  before_action :set_person
  after_action :verify_authorized

  def show
    authorize @person, :manager?, policy_class: PersonPolicy
    load_assignments_and_check_ins
  end

  def update
    authorize @person, :manager?, policy_class: PersonPolicy
    
    # Load assignment data before processing updates
    load_assignments_and_check_ins
    
    if update_assignments_and_check_ins
      redirect_to person_assignment_tenures_path(@person), notice: 'Assignments updated successfully.'
    else
      render :show, status: :unprocessable_entity
    end
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
    # Get assignments for a specific company that could be added to this person
    current_assignments = load_person_assignments
    company_assignments = Assignment.includes(:company)
                                   .where(company: company)
                                   .order(:title)
    
    company_assignments.reject { |assignment| current_assignments.include?(assignment) }
  end

  def load_person_current_position
    # Get the person's current active employment tenure and position
    current_employment = @person.employment_tenures.active.first
    current_employment&.position
  end

  def group_assignments_by_organization
    # Group available assignments by organization
    @available_assignments.group_by(&:company)
  end

  def assignment_type_for_position(assignment)
    return nil unless @person_position
    
    position_assignment = @person_position.position_assignments.find_by(assignment: assignment)
    position_assignment&.assignment_type
  end

  def has_assignment_history?(assignment)
    # Check if person has any check-ins or tenures for this assignment
    @person.assignment_tenures.where(assignment: assignment).exists? ||
    @person.assignment_check_ins.where(assignment: assignment).exists?
  end

  helper_method :assignment_type_for_position, :has_assignment_history?

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
        if check_in_params_present?(assignment.id)
          update_or_create_check_in(open_check_in, assignment)
        end
      end
      
      # Also process any assignments that have parameters but are not in the loaded data
      # This handles cases where assignments are not properly associated with the position
      processed_assignment_ids = Set.new
      
      params.each do |key, value|
        if key.start_with?('tenure_') && key.end_with?('_anticipated_energy')
          assignment_id = key.gsub('tenure_', '').gsub('_anticipated_energy', '').to_i
          assignment = Assignment.find_by(id: assignment_id)
          
          if assignment && !@assignment_data.any? { |data| data[:assignment].id == assignment_id }
            tenure = AssignmentTenure.most_recent_for(@person, assignment)
            update_or_create_tenure(assignment, tenure)
            processed_assignment_ids.add(assignment_id)
          end
        end
      end
      
      # Also process check-in parameters for assignments not in loaded data
      params.each do |key, value|
        if key.start_with?('check_in_') && (key.end_with?('_actual_energy') || key.end_with?('_employee_rating') || key.end_with?('_personal_alignment') || key.end_with?('_employee_private_notes') || key.end_with?('_manager_rating') || key.end_with?('_manager_private_notes') || key.end_with?('_employee_complete') || key.end_with?('_manager_complete'))
          assignment_id = key.gsub('check_in_', '').split('_')[0].to_i
          assignment = Assignment.find_by(id: assignment_id)
          
          if assignment && !@assignment_data.any? { |data| data[:assignment].id == assignment_id } && !processed_assignment_ids.include?(assignment_id)
            open_check_in = AssignmentCheckIn.where(person: @person, assignment: assignment).open.first
            update_or_create_check_in(open_check_in, assignment)
          end
        end
      end
      
      true
    rescue => e
      Rails.logger.error "Error updating assignments: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
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

  def check_in_params_present?(assignment_id)
    params["check_in_#{assignment_id}_actual_energy"].present? ||
    params["check_in_#{assignment_id}_employee_rating"].present? ||
    params["check_in_#{assignment_id}_personal_alignment"].present? ||
    params["check_in_#{assignment_id}_employee_private_notes"].present? ||
    params["check_in_#{assignment_id}_manager_rating"].present? ||
    params["check_in_#{assignment_id}_manager_private_notes"].present? ||
    params["check_in_#{assignment_id}_employee_complete"].present? ||
    params["check_in_#{assignment_id}_manager_complete"].present?
  end

  def update_or_create_tenure(assignment, existing_tenure)
    # If energy percentage changed, end current tenure and create new one
    new_energy = params["tenure_#{assignment.id}_anticipated_energy"].to_i
    
    if existing_tenure && existing_tenure.anticipated_energy_percentage != new_energy
      # End current tenure and start new one today
      existing_tenure.update!(ended_at: Date.current + 1.day)
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
      update_params = {
        actual_energy_percentage: params["check_in_#{assignment.id}_actual_energy"].to_i,
        employee_rating: params["check_in_#{assignment.id}_employee_rating"],
        employee_personal_alignment: params["check_in_#{assignment.id}_personal_alignment"],
        employee_private_notes: params["check_in_#{assignment.id}_employee_private_notes"],
        manager_rating: params["check_in_#{assignment.id}_manager_rating"],
        manager_private_notes: params["check_in_#{assignment.id}_manager_private_notes"]
      }
      
      existing_check_in.update!(update_params)
      
      # Handle completion toggles
      if params["check_in_#{assignment.id}_employee_complete"] == "1"
        existing_check_in.complete_employee_side!(completed_by: current_person) unless existing_check_in.employee_completed?
      else
        existing_check_in.uncomplete_employee_side! if existing_check_in.employee_completed?
      end
      
      if params["check_in_#{assignment.id}_manager_complete"] == "1"
        existing_check_in.complete_manager_side!(completed_by: current_person) unless existing_check_in.manager_completed?
      else
        existing_check_in.uncomplete_manager_side! if existing_check_in.manager_completed?
      end
    else
      # Create new check-in - only if at least one field has a value
      actual_energy = params["check_in_#{assignment.id}_actual_energy"]
      employee_rating = params["check_in_#{assignment.id}_employee_rating"]
      personal_alignment = params["check_in_#{assignment.id}_personal_alignment"]
      employee_private_notes = params["check_in_#{assignment.id}_employee_private_notes"]
      manager_rating = params["check_in_#{assignment.id}_manager_rating"]
      manager_private_notes = params["check_in_#{assignment.id}_manager_private_notes"]
      
      # Only create if at least one field has a value
      return unless actual_energy.present? || employee_rating.present? || personal_alignment.present? || 
                   employee_private_notes.present? || manager_rating.present? || manager_private_notes.present?
      
      check_in = AssignmentCheckIn.create!(
        person: @person,
        assignment: assignment,
        check_in_started_on: Date.current,
        actual_energy_percentage: actual_energy.to_i,
        employee_rating: employee_rating,
        employee_personal_alignment: personal_alignment,
        employee_private_notes: employee_private_notes,
        manager_rating: manager_rating,
        manager_private_notes: manager_private_notes
      )
      
      # Handle completion toggles for new check-in
      if params["check_in_#{assignment.id}_employee_complete"] == "1"
        check_in.complete_employee_side!(completed_by: current_person)
      end
      
      if params["check_in_#{assignment.id}_manager_complete"] == "1"
        check_in.complete_manager_side!(completed_by: current_person)
      end
    end
  end

  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access assignment management.'
    end
  end
end
