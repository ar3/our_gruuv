module CheckInBehavior
  extend ActiveSupport::Concern
  
  included do
    # Common associations
    belongs_to :teammate
    belongs_to :finalized_by, class_name: 'Person', optional: true
    belongs_to :maap_snapshot, optional: true
    
    # Common validations
    validates :check_in_started_on, presence: true
    
    # Common scopes
    scope :recent, -> { order(check_in_started_on: :desc) }
    scope :for_teammate, ->(teammate) { where(teammate: teammate) }
    scope :open, -> { where(official_check_in_completed_at: nil) }
    scope :closed, -> { where.not(official_check_in_completed_at: nil) }
    scope :employee_completed, -> { where.not(employee_completed_at: nil) }
    scope :manager_completed, -> { where.not(manager_completed_at: nil) }
    scope :ready_for_finalization, -> { 
      where.not(employee_completed_at: nil)
           .where.not(manager_completed_at: nil)
           .where(official_check_in_completed_at: nil) 
    }
  end
  
  # Status methods
  def open?
    official_check_in_completed_at.nil?
  end
  
  def closed?
    !open?
  end
  
  def employee_completed?
    employee_completed_at.present?
  end
  
  def manager_completed?
    manager_completed_at.present?
  end
  
  def officially_completed?
    official_check_in_completed_at.present?
  end
  
  def ready_for_finalization?
    employee_completed? && manager_completed? && !officially_completed?
  end
  
  # Completion actions
  def complete_employee_side!
    update!(employee_completed_at: Time.current)
  end
  
  def complete_manager_side!(completed_by:)
    update!(
      manager_completed_at: Time.current,
      manager_completed_by: completed_by
    )
  end
  
  def uncomplete_employee_side!
    update!(employee_completed_at: nil)
  end
  
  def uncomplete_manager_side!
    update!(
      manager_completed_at: nil,
      manager_completed_by: nil
    )
  end
end




