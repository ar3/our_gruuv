class MaapSnapshot < ApplicationRecord
  # Core relationships (optional for exploration snapshots)
  belongs_to :employee_company_teammate, class_name: 'CompanyTeammate', optional: true
  belongs_to :creator_company_teammate, class_name: 'CompanyTeammate', optional: true
  belongs_to :company, class_name: 'Organization', optional: true

  # Check-ins linked when this snapshot was created by check-in finalization
  has_one :position_check_in, dependent: nil
  has_many :assignment_check_ins, dependent: nil
  has_many :aspiration_check_ins, dependent: nil
  
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
  scope :for_employee_teammate, ->(teammate) { where(employee_company_teammate: teammate) }
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
  def self.build_for_employee(employee_teammate:, creator_teammate:, change_type:, reason:, request_info: {})
    company = employee_teammate.organization
    new(
      employee_company_teammate: employee_teammate,
      creator_company_teammate: creator_teammate,
      company: company,
      change_type: change_type,
      reason: reason,
      manager_request_info: request_info,
      maap_data: build_maap_data_for_teammate(employee_teammate)
    )
  end
  
  def self.build_for_employee_with_changes(employee_teammate:, creator_teammate:, change_type:, reason:, request_info: {}, form_params: {})
    # Find the company from the employee teammate
    company = employee_teammate.organization
    new(
      employee_company_teammate: employee_teammate,
      creator_company_teammate: creator_teammate,
      company: company,
      change_type: change_type,
      reason: reason,
      manager_request_info: request_info,
      form_params: form_params,
      # maap_data should always reflect DB state (post-execution log)
      # Proposed changes are stored in form_params only
      maap_data: build_maap_data_for_teammate(employee_teammate)
    )
  end

  def self.build_for_employee_without_maap_data(employee_teammate:, creator_teammate:, change_type:, reason:, request_info: {}, form_params: {})
    company = employee_teammate.organization
    new(
      employee_company_teammate: employee_teammate,
      creator_company_teammate: creator_teammate,
      company: company,
      change_type: change_type,
      reason: reason,
      manager_request_info: request_info,
      form_params: form_params,
      maap_data: nil
    )
  end
  
  def self.build_exploration(creator_teammate:, company:, reason:, request_info: {})
    new(
      employee_company_teammate: nil,
      creator_company_teammate: creator_teammate,
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
    where(employee_company_teammate: teammate, employee_acknowledged_at: nil)
      .where.not(effective_date: nil)
  end
  
  def primary_potential_observer
    employee_company_teammate
  end

  # Check-ins linked to this snapshot (from finalization). Used for audit check-in sentence display.
  def linked_position_check_in
    position_check_in
  end

  def linked_assignment_check_ins
    assignment_check_ins
  end

  def linked_aspiration_check_ins
    aspiration_check_ins
  end

  private
  
  def self.build_maap_data_for_teammate(teammate)
    {
      position: build_position_data(teammate),
      assignments: build_assignments_data(teammate),
      abilities: build_abilities_data(teammate),
      aspirations: build_aspirations_data(teammate)
    }
  end
  
  def self.build_position_data(teammate)
    return nil unless teammate
    company = teammate.organization
    active_employment = EmploymentTenure.where(company_teammate: teammate).active.where(company: company).first
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
  
  def self.build_assignments_data(teammate)
    return [] unless teammate
    company = teammate.organization
    
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
  
  def self.build_abilities_data(teammate)
    return [] unless teammate
    company = teammate.organization
    TeammateMilestone.where(company_teammate: teammate).joins(:ability).where(abilities: { company_id: company.id }).includes(:ability).map do |milestone|
      {
        ability_id: milestone.ability_id,
        milestone_level: milestone.milestone_level,
        certifying_teammate_id: milestone.certifying_teammate_id,
        attained_at: milestone.attained_at
      }
    end
  end
  
  def self.build_aspirations_data(teammate)
    return [] unless teammate
    company = teammate.organization
    
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
