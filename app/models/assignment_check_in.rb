class AssignmentCheckIn < ApplicationRecord
  belongs_to :teammate
  belongs_to :assignment
  belongs_to :manager_completed_by, class_name: 'Person', optional: true
  belongs_to :finalized_by, class_name: 'Person', optional: true

  # Enums for ratings
  enum :employee_rating, {
    working_to_meet: 'working_to_meet',
    meeting: 'meeting',
    exceeding: 'exceeding'
  }, prefix: true

  enum :manager_rating, {
    working_to_meet: 'working_to_meet',
    meeting: 'meeting',
    exceeding: 'exceeding'
  }, prefix: true

  enum :official_rating, {
    working_to_meet: 'working_to_meet',
    meeting: 'meeting',
    exceeding: 'exceeding'
  }, prefix: true

  # Enum for personal alignment
  enum :employee_personal_alignment, {
    love: 'love',
    like: 'like',
    neutral: 'neutral',
    prefer_not: 'prefer_not',
    only_if_necessary: 'only_if_necessary'
  }, prefix: true

  # Validations
  validates :check_in_started_on, presence: true
  validates :actual_energy_percentage, 
            inclusion: { in: 0..100 }, 
            allow_nil: true
  validates :employee_rating, inclusion: { in: employee_ratings.keys }, allow_nil: true
  validates :manager_rating, inclusion: { in: manager_ratings.keys }, allow_nil: true
  validates :official_rating, inclusion: { in: official_ratings.keys }, allow_nil: true
  validates :employee_personal_alignment, inclusion: { in: employee_personal_alignments.keys }, allow_nil: true
  
  # Custom validation to prevent multiple open check-ins per teammate per assignment
  validate :only_one_open_check_in_per_teammate_assignment

  # Scopes
  scope :recent, -> { order(check_in_started_on: :desc) }
  scope :for_teammate, ->(teammate) { where(teammate: teammate) }
  scope :for_assignment, ->(assignment) { where(assignment: assignment) }
  scope :open, -> { where(official_check_in_completed_at: nil) }
  scope :closed, -> { where.not(official_check_in_completed_at: nil) }
  
  # Completion tracking scopes
  scope :employee_completed, -> { where.not(employee_completed_at: nil) }
  scope :manager_completed, -> { where.not(manager_completed_at: nil) }
  scope :officially_completed, -> { where.not(official_check_in_completed_at: nil) }
  scope :ready_for_finalization, -> { where.not(employee_completed_at: nil).where.not(manager_completed_at: nil).where(official_check_in_completed_at: nil) }
  scope :not_ready_for_finalization, -> { where(employee_completed_at: nil).or(where(manager_completed_at: nil)) }

  # Instance methods
  def rating_display
    return 'Not Rated' if employee_rating.blank? && manager_rating.blank? && official_rating.blank?
    
    ratings = []
    ratings << "Employee: #{employee_rating&.humanize}" if employee_rating.present?
    ratings << "Manager: #{manager_rating&.humanize}" if manager_rating.present?
    ratings << "Official: #{official_rating&.humanize}" if official_rating.present?
    
    ratings.join(' | ')
  end

  def energy_mismatch?
    return false unless actual_energy_percentage && assignment_tenure&.anticipated_energy_percentage
    
    difference = (actual_energy_percentage - assignment_tenure.anticipated_energy_percentage).abs
    difference > 20 # Flag if difference is more than 20%
  end

  def days_since_tenure_start
    return nil unless assignment_tenure&.started_at
    
    (check_in_started_on - assignment_tenure.started_at.to_date).to_i
  end

  def open?
    official_check_in_completed_at.nil?
  end

  def closed?
    !open?
  end

  def self.average_days_between_check_ins(teammate)
    check_ins = for_teammate(teammate).order(:check_in_started_on)
    return nil if check_ins.count < 2
    
    total_days = 0
    check_ins.each_cons(2) do |first, second|
      total_days += (second.check_in_started_on - first.check_in_started_on).to_i
    end
    
    total_days.to_f / (check_ins.count - 1)
  end

  # Find the associated assignment tenure for this check-in
  def assignment_tenure
    @assignment_tenure ||= AssignmentTenure.most_recent_for(teammate.person, assignment)
  end

  # Find or create open check-in for a teammate and assignment
  def self.find_or_create_open_for(teammate, assignment)
    tenure = AssignmentTenure.most_recent_for(teammate.person, assignment)
    return nil unless tenure
    
    # Find existing open check-in for this teammate/assignment
    open_check_in = where(teammate: teammate, assignment: assignment).open.first
    return open_check_in if open_check_in
    
    # Create new open check-in if none exists
    create!(
      teammate: teammate,
      assignment: assignment,
      check_in_started_on: Date.current,
      actual_energy_percentage: tenure.anticipated_energy_percentage
    )
  end

  # Completion tracking methods
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

  def employee_started?
    actual_energy_percentage.present? || employee_personal_alignment.present? || employee_rating.present? || employee_private_notes.present?
  end

  def manager_started?
    manager_rating.present? || manager_private_notes.present?
  end

  def complete_employee_side!(completed_by: nil)
    update!(
      employee_completed_at: Time.current
    )
  end

  def complete_manager_side!(completed_by: nil)
    update!(
      manager_completed_at: Time.current,
      manager_completed_by: completed_by
    )
  end

  def uncomplete_employee_side!
    update!(
      employee_completed_at: nil
    )
  end

  def uncomplete_manager_side!
    update!(
      manager_completed_at: nil,
      manager_completed_by: nil
    )
  end

  def finalize_check_in!(final_rating: nil, finalized_by: nil)
    raise ArgumentError, "Final rating is required for check-in finalization" if final_rating.blank?
    
    update!(
      official_check_in_completed_at: Time.current,
      official_rating: final_rating,
      finalized_by: finalized_by
    )
  end

  private

  def only_one_open_check_in_per_teammate_assignment
    return unless open? # Only validate for open check-ins
    
    existing_open = AssignmentCheckIn
      .where(teammate: teammate, assignment: assignment)
      .open
      .where.not(id: id)
    
    if existing_open.exists?
      errors.add(:base, "Only one open check-in allowed per teammate per assignment")
    end
  end
end
