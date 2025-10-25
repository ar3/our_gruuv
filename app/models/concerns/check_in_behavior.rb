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
  
  # Completion state methods (only for OPEN check-ins)
  def completion_state
    return :both_complete if employee_completed? && manager_completed?
    return :manager_complete_employee_open if manager_completed? && !employee_completed?
    return :manager_open_employee_complete if !manager_completed? && employee_completed?
    :both_open
  end

  def both_open?
    completion_state == :both_open
  end

  def manager_open_employee_complete?
    completion_state == :manager_open_employee_complete
  end

  def manager_complete_employee_open?
    completion_state == :manager_complete_employee_open
  end

  def both_complete?
    completion_state == :both_complete
  end
  
  # Returns the partial suffix for the viewer's own fields
  # Returns: :show_open_fields or :show_complete_summary
  def viewer_display_mode(viewer_role)
    case viewer_role
    when :employee
      case completion_state
      when :both_open, :manager_complete_employee_open
        :show_open_fields
      when :manager_open_employee_complete, :both_complete
        :show_complete_summary
      end
    when :manager
      case completion_state
      when :both_open, :manager_open_employee_complete
        :show_open_fields
      when :manager_complete_employee_open, :both_complete
        :show_complete_summary
      end
    when :readonly
      # For readonly mode, always show open fields (read-only version)
      :show_open_fields
    end
  end

  # Returns the partial suffix for showing other participant's status
  # Returns: :show_other_participant_is_complete or :show_other_participant_is_incomplete
  def other_participant_display_mode(viewer_role)
    case viewer_role
    when :employee
      case completion_state
      when :both_open, :manager_open_employee_complete
        :show_other_participant_is_incomplete
      when :manager_complete_employee_open, :both_complete
        :show_other_participant_is_complete
      end
    when :manager
      case completion_state
      when :both_open, :manager_complete_employee_open
        :show_other_participant_is_incomplete
      when :manager_open_employee_complete, :both_complete
        :show_other_participant_is_complete
      end
    when :readonly
      # For readonly mode, show based on completion state
      case completion_state
      when :both_open, :manager_open_employee_complete, :manager_complete_employee_open
        :show_other_participant_is_incomplete
      when :both_complete
        :show_other_participant_is_complete
      end
    end
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




