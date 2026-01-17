class PositionCheckIn < ApplicationRecord
  include CheckInBehavior
  
  belongs_to :teammate
  belongs_to :employment_tenure
  belongs_to :manager_completed_by, class_name: 'Person', optional: true
  belongs_to :finalized_by, class_name: 'Person', optional: true
  
  # Virtual attribute for form handling
  attr_accessor :status
  
  validates :employee_rating, inclusion: { in: -3..3 }, allow_nil: true
  validates :manager_rating, inclusion: { in: -3..3 }, allow_nil: true
  validates :official_rating, inclusion: { in: -3..3 }, allow_nil: true
  
  validate :only_one_open_check_in_per_teammate
  
  # Find or create open check-in for a teammate
  def self.find_or_create_open_for(teammate)
    # Only CompanyTeammate has active_employment_tenure method
    tenure = if teammate.is_a?(CompanyTeammate)
      teammate.active_employment_tenure
    else
      teammate.employment_tenures.active.where(company: teammate.organization).first
    end
    return nil unless tenure
    
    open_check_in = where(teammate: teammate).open.first
    return open_check_in if open_check_in
    
    create!(
      teammate: teammate,
      employment_tenure: tenure,
      check_in_started_on: Date.current
    )
  end
  
  # Find the latest finalized check-in for a teammate (across all employment tenures)
  def self.latest_finalized_for(teammate)
    where(teammate: teammate)
      .closed
      .order(official_check_in_completed_at: :desc)
      .first
  end

  def previous_finalized_check_in
    @previous_finalized_check_in ||= PositionCheckIn
      .where(teammate: teammate)
      .closed
      .order(:official_check_in_completed_at)
      .last
  end
  
  private
  
  def only_one_open_check_in_per_teammate
    return unless open?
    
    existing_open = PositionCheckIn
      .where(teammate: teammate)
      .open
      .where.not(id: id)
    
    if existing_open.exists?
      errors.add(:base, "Only one open position check-in allowed per teammate")
    end
  end
end
