class MaapSnapshot < ApplicationRecord
  # Core relationships (optional for exploration snapshots)
  belongs_to :employee, class_name: 'Person', optional: true
  belongs_to :created_by, class_name: 'Person', optional: true
  belongs_to :company, class_name: 'Organization', optional: true
  
  # Change metadata
  validates :change_type, presence: true, inclusion: { 
    in: %w[assignment_management position_tenure milestone_management aspiration_management exploration bulk_update bulk_check_in_finalization] 
  }
  validates :reason, presence: true
  validates :company, presence: true
  
  # Full MAAP data as JSONB (structured for easy querying)
  # maap_data contains: employment_tenure, assignments, milestones, aspirations
  
  # Form parameters as JSONB (raw form submission data)
  # form_params contains: return_to_check_ins, original_organization_id, check_in_*_*, etc.
  
  # Security audit trail
  # request_info contains: ip_address, user_agent, session_id, request_id, timestamp
  
  # Effective date (nil until executed)
  validates :effective_date, presence: false
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_change_type, ->(type) { where(change_type: type) }
  scope :for_employee, ->(employee) { where(employee: employee) }
  scope :for_company, ->(company) { where(company: company) }
  scope :exploration, -> { where(change_type: 'exploration') }
  scope :executed, -> { where.not(effective_date: nil) }
  scope :pending, -> { where(effective_date: nil) }
  
  # Instance methods
  def executed?
    effective_date.present?
  end
  
  def pending?
    effective_date.nil?
  end
  
  def exploration_snapshot?
    change_type == 'exploration'
  end
  
  # Class methods for building snapshots
  def self.build_for_employee(employee:, created_by:, change_type:, reason:, request_info: {})
    new(
      employee: employee,
      created_by: created_by,
      company: employee.employment_tenures.active.first&.company,
      change_type: change_type,
      reason: reason,
      request_info: request_info,
      maap_data: build_maap_data_for_employee(employee)
    )
  end
  
  def self.build_for_employee_with_changes(employee:, created_by:, change_type:, reason:, request_info: {}, form_params: {})
    new(
      employee: employee,
      created_by: created_by,
      company: employee.employment_tenures.active.first&.company,
      change_type: change_type,
      reason: reason,
      request_info: request_info,
      form_params: form_params,
      maap_data: build_maap_data_for_employee_with_changes(employee, form_params)
    )
  end
  
  def self.build_exploration(created_by:, company:, reason:, request_info: {})
    new(
      employee: nil,
      created_by: created_by,
      company: company,
      change_type: 'exploration',
      reason: reason,
      request_info: request_info,
      maap_data: {}
    )
  end
  

  private
  
  def self.build_maap_data_for_employee(employee)
    {
      employment_tenure: build_employment_tenure_data(employee),
      assignments: build_assignments_data(employee),
      milestones: build_milestones_data(employee),
      aspirations: build_aspirations_data(employee)
    }
  end
  
  def self.build_maap_data_for_employee_with_changes(employee, form_params)
    {
      employment_tenure: build_employment_tenure_data(employee),
      assignments: build_assignments_data_with_changes(employee, form_params),
      milestones: build_milestones_data(employee),
      aspirations: build_aspirations_data(employee)
    }
  end
  
  def self.build_employment_tenure_data(employee)
    employment = employee.employment_tenures.active.first
    return nil unless employment
    
    {
      position_id: employment.position_id,
      manager_id: employment.manager_id,
      started_at: employment.started_at,
      seat_id: employment.seat_id
    }
  end
  
  def self.build_assignments_data(employee)
    employee.assignment_tenures.active.includes(:assignment).map do |tenure|
      check_in = AssignmentCheckIn.where(person: employee, assignment: tenure.assignment).open.first
      
      {
        id: tenure.assignment_id,
        tenure: {
          anticipated_energy_percentage: tenure.anticipated_energy_percentage,
          started_at: tenure.started_at
        },
        employee_check_in: check_in ? {
          actual_energy_percentage: check_in.actual_energy_percentage,
          employee_rating: check_in.employee_rating,
          employee_completed_at: check_in.employee_completed_at,
          employee_private_notes: check_in.employee_private_notes,
          employee_personal_alignment: check_in.employee_personal_alignment
        } : nil,
        manager_check_in: check_in ? {
          manager_rating: check_in.manager_rating,
          manager_completed_at: check_in.manager_completed_at,
          manager_private_notes: check_in.manager_private_notes,
          manager_completed_by_id: check_in.manager_completed_by_id
        } : nil,
        official_check_in: check_in ? {
          official_rating: check_in.official_rating,
          shared_notes: check_in.shared_notes,
          official_check_in_completed_at: check_in.official_check_in_completed_at,
          finalized_by_id: check_in.finalized_by_id
        } : nil
      }
    end
  end
  
  def self.build_assignments_data_with_changes(employee, form_params)
    # Get all assignments where the person has ever had a tenure
    assignment_ids = employee.assignment_tenures.distinct.pluck(:assignment_id)
    assignments = Assignment.where(id: assignment_ids).includes(:assignment_tenures)
    
    assignments.map do |assignment|
      current_tenure = employee.assignment_tenures.where(assignment: assignment).active.first
      current_check_in = AssignmentCheckIn.where(person: employee, assignment: assignment).open.first
      
      # Extract form parameters for this assignment
      assignment_id = assignment.id
      
      # Build tenure data with form changes
      tenure_data = build_tenure_data_with_changes(current_tenure, form_params, assignment_id)
      
      # Build check-in data with form changes
      employee_check_in_data = build_employee_check_in_data_with_changes(current_check_in, form_params, assignment_id)
      manager_check_in_data = build_manager_check_in_data_with_changes(current_check_in, form_params, assignment_id)
      official_check_in_data = build_official_check_in_data_with_changes(current_check_in, form_params, assignment_id)
      
      {
        id: assignment_id,
        tenure: tenure_data,
        employee_check_in: employee_check_in_data,
        manager_check_in: manager_check_in_data,
        official_check_in: official_check_in_data
      }
    end
  end
  
  def self.build_milestones_data(employee)
    employee.person_milestones.includes(:ability).map do |milestone|
      {
        ability_id: milestone.ability_id,
        milestone_level: milestone.milestone_level,
        person_id: milestone.person_id,
        certified_by_id: milestone.certified_by_id,
        attained_at: milestone.attained_at
      }
    end
  end
  
  def self.build_aspirations_data(employee)
    # TODO: Implement when aspiration model exists
    []
  end
  
  # Helper methods for processing form changes
  def self.build_tenure_data_with_changes(current_tenure, form_params, assignment_id)
    # Get form value for anticipated energy percentage
    form_energy = form_params["tenure_#{assignment_id}_anticipated_energy"]
    
    if form_energy.present?
      # Use form value
      {
        anticipated_energy_percentage: form_energy.to_i,
        started_at: current_tenure&.started_at || Date.current
      }
    elsif current_tenure
      # Use current value
      {
        anticipated_energy_percentage: current_tenure.anticipated_energy_percentage,
        started_at: current_tenure.started_at
      }
    else
      # No current tenure and no form value
      {
        anticipated_energy_percentage: 0,
        started_at: Date.current
      }
    end
  end
  
  def self.build_employee_check_in_data_with_changes(current_check_in, form_params, assignment_id)
    # Check if there are any employee check-in form parameters
    actual_energy = form_params["check_in_#{assignment_id}_actual_energy"]
    employee_rating = form_params["check_in_#{assignment_id}_employee_rating"]
    employee_private_notes = form_params["check_in_#{assignment_id}_employee_private_notes"]
    employee_personal_alignment = form_params["check_in_#{assignment_id}_personal_alignment"]
    employee_complete = form_params["check_in_#{assignment_id}_employee_complete"] == "1"
    
    # Only include if there are form changes or current data
    if actual_energy.present? || employee_rating.present? || employee_private_notes.present? || 
       employee_personal_alignment.present? || employee_complete || current_check_in
      
      {
        actual_energy_percentage: actual_energy.present? ? actual_energy.to_i : current_check_in&.actual_energy_percentage,
        employee_rating: employee_rating.present? ? employee_rating : current_check_in&.employee_rating,
        employee_completed_at: employee_complete ? Time.current : current_check_in&.employee_completed_at,
        employee_private_notes: employee_private_notes.present? ? employee_private_notes : current_check_in&.employee_private_notes,
        employee_personal_alignment: employee_personal_alignment.present? ? employee_personal_alignment : current_check_in&.employee_personal_alignment
      }
    else
      nil
    end
  end
  
  def self.build_manager_check_in_data_with_changes(current_check_in, form_params, assignment_id)
    # Check if there are any manager check-in form parameters
    manager_rating = form_params["check_in_#{assignment_id}_manager_rating"]
    manager_private_notes = form_params["check_in_#{assignment_id}_manager_private_notes"]
    manager_complete = form_params["check_in_#{assignment_id}_manager_complete"] == "1"
    
    # Only include if there are form changes or current data
    if manager_rating.present? || manager_private_notes.present? || manager_complete || current_check_in
      
      {
        manager_rating: manager_rating.present? ? manager_rating : current_check_in&.manager_rating,
        manager_completed_at: manager_complete ? Time.current : current_check_in&.manager_completed_at,
        manager_private_notes: manager_private_notes.present? ? manager_private_notes : current_check_in&.manager_private_notes,
        manager_completed_by_id: manager_complete ? form_params[:created_by_id] : current_check_in&.manager_completed_by_id
      }
    else
      nil
    end
  end
  
  def self.build_official_check_in_data_with_changes(current_check_in, form_params, assignment_id)
    # Check if there are any official check-in form parameters
    # Handle both bulk finalization format (check_in_#{check_in_id}_*) and regular format (check_in_#{assignment_id}_*)
    check_in_id = current_check_in&.id
    
    official_rating = form_params["check_in_#{check_in_id}_final_rating"] || form_params["check_in_#{assignment_id}_official_rating"]
    shared_notes = form_params["check_in_#{check_in_id}_shared_notes"] || form_params["check_in_#{assignment_id}_shared_notes"]
    official_complete = form_params["check_in_#{check_in_id}_close_rating"] == "true" || form_params["check_in_#{assignment_id}_official_complete"] == "1"
    
    # Only include if there are form changes or current data
    if official_rating.present? || shared_notes.present? || official_complete || current_check_in
      
      {
        official_rating: official_rating.present? ? official_rating : current_check_in&.official_rating,
        shared_notes: shared_notes.present? ? shared_notes : current_check_in&.shared_notes,
        official_check_in_completed_at: official_complete ? Time.current : current_check_in&.official_check_in_completed_at,
        finalized_by_id: official_complete ? form_params[:created_by_id] : current_check_in&.finalized_by_id
      }
    else
      nil
    end
  end
end
