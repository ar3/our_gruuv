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
  validates :maap_data, presence: true
  
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
    company = employee.teammates.joins(:employment_tenures).where(employment_tenures: { ended_at: nil }).first&.employment_tenures&.active&.first&.company
    new(
      employee: employee,
      created_by: created_by,
      company: company,
      change_type: change_type,
      reason: reason,
      manager_request_info: request_info,
      maap_data: build_maap_data_for_employee(employee, company)
    )
  end
  
  def self.build_for_employee_with_changes(employee:, created_by:, change_type:, reason:, request_info: {}, form_params: {})
    # Find the company from the employee's teammates
    company = employee.teammates.joins(:employment_tenures).where(employment_tenures: { ended_at: nil }).first&.organization
    new(
      employee: employee,
      created_by: created_by,
      company: company,
      change_type: change_type,
      reason: reason,
      manager_request_info: request_info,
      form_params: form_params,
      # maap_data should always reflect DB state (post-execution log)
      # Proposed changes are stored in form_params only
      maap_data: build_maap_data_for_employee(employee, company)
    )
  end

  def self.build_for_employee_without_maap_data(employee:, created_by:, change_type:, reason:, request_info: {}, form_params: {})
    company = employee.teammates.joins(:employment_tenures).where(employment_tenures: { ended_at: nil }).first&.employment_tenures&.active&.first&.company
    new(
      employee: employee,
      created_by: created_by,
      company: company,
      change_type: change_type,
      reason: reason,
      manager_request_info: request_info,
      form_params: form_params,
      maap_data: nil
    )
  end
  
  def self.build_exploration(created_by:, company:, reason:, request_info: {})
    new(
      employee: nil,
      created_by: created_by,
      company: company,
      change_type: 'exploration',
      reason: reason,
      manager_request_info: request_info,
      maap_data: {}
    )
  end

  def process_with_processor!
    processor_class = "MaapData::#{change_type.classify}Processor".constantize
    processor = processor_class.new(self)
    self.maap_data = processor.process
    save!
  end
  

  # Acknowledgement methods
  def acknowledged?
    employee_acknowledged_at.present?
  end

  def pending_acknowledgement?
    effective_date.present? && employee_acknowledged_at.nil?
  end
  
  def self.pending_acknowledgement_for(teammate)
    where(employee: teammate.person, employee_acknowledged_at: nil)
      .where.not(effective_date: nil)
  end
  
  def primary_potential_observer
    return nil unless employee
    employee.teammates.find_by(organization: company)
  end

  private
  
  def self.build_maap_data_for_employee(employee, company)
    {
      position: build_position_data(employee, company),
      assignments: build_assignments_data(employee, company),
      abilities: build_abilities_data(employee, company),
      aspirations: build_aspirations_data(employee, company)
    }
  end
  
  def self.build_position_data(employee, company)
    teammate = employee.teammates.find_by(organization: company)
    return nil unless teammate
    active_employment = EmploymentTenure.where(teammate: teammate).active.where(company: company).first
    return nil unless active_employment
    
    # Find most recent closed employment tenure
    previous_closed_tenure = teammate.employment_tenures
      .for_company(company)
      .inactive
      .order(ended_at: :desc)
      .first
    
    rated_position = if previous_closed_tenure
      {
        seat_id: previous_closed_tenure.seat_id,
        manager_teammate_id: previous_closed_tenure.manager_teammate_id,
        position_id: previous_closed_tenure.position_id,
        employment_type: previous_closed_tenure.employment_type,
        official_position_rating: previous_closed_tenure.official_position_rating,
        started_at: previous_closed_tenure.started_at.to_time.iso8601,
        ended_at: previous_closed_tenure.ended_at.to_time.iso8601
      }
    else
      {}
    end
    
    {
      position_id: active_employment.position_id,
      manager_teammate_id: active_employment.manager_teammate_id,
      seat_id: active_employment.seat_id,
      employment_type: active_employment.employment_type,
      rated_position: rated_position
    }
  end
  
  def self.build_assignments_data(employee, company)
    teammate = employee.teammates.find_by(organization: company)
    return [] unless teammate
    
    teammate.assignment_tenures.active.includes(:assignment).joins(:assignment).where(assignments: { company: company }).map do |active_tenure|
      # Find most recent closed assignment tenure for this assignment
      previous_closed_tenure = teammate.assignment_tenures
        .where(assignment: active_tenure.assignment)
        .where.not(ended_at: nil)
        .order(ended_at: :desc)
        .first
      
      rated_assignment = if previous_closed_tenure
        {
          assignment_id: previous_closed_tenure.assignment_id,
          anticipated_energy_percentage: previous_closed_tenure.anticipated_energy_percentage,
          official_rating: previous_closed_tenure.official_rating,
          started_at: previous_closed_tenure.started_at.to_time.iso8601,
          ended_at: previous_closed_tenure.ended_at.to_time.iso8601
        }
      else
        {}
      end
      
      {
        assignment_id: active_tenure.assignment_id,
        anticipated_energy_percentage: active_tenure.anticipated_energy_percentage,
        rated_assignment: rated_assignment
      }
    end
  end
  
  def self.build_abilities_data(employee, company)
    teammate = employee.teammates.find_by(organization: company)
    return [] unless teammate
    TeammateMilestone.where(teammate: teammate).joins(:ability).where(abilities: { organization: company }).includes(:ability).map do |milestone|
      {
        ability_id: milestone.ability_id,
        milestone_level: milestone.milestone_level,
        certified_by_id: milestone.certified_by_id,
        attained_at: milestone.attained_at
      }
    end
  end
  
  def self.build_aspirations_data(employee, company)
    teammate = employee.teammates.find_by(organization: company)
    return [] unless teammate
    
    # Get all aspirations for the company
    aspirations = company.aspirations
    
    aspirations.map do |aspiration|
      # Get the last finalized aspiration_check_in for this teammate and aspiration
      finalized_check_in = AspirationCheckIn.latest_finalized_for(teammate, aspiration)
      
      {
        aspiration_id: aspiration.id,
        official_rating: finalized_check_in&.official_rating
      }
    end
  end
  
  # Helper methods to extract full rating data (with context like IDs)
  def position_data
    maap_data['position']
  end

  def assignment_ratings_data
    maap_data['assignments'] || []
  end

  def abilities_data
    maap_data['abilities'] || []
  end

  def aspiration_ratings_data
    maap_data['aspirations'] || []
  end

  # Convenience method for counts
  def ability_count
    abilities_data.count
  end

end
