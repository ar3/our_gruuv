class AssignmentCheckIn < ApplicationRecord
  belongs_to :person
  belongs_to :assignment

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
  
  # Custom validation to prevent multiple open check-ins per person per assignment
  validate :only_one_open_check_in_per_person_assignment

  # Scopes
  scope :recent, -> { order(check_in_started_on: :desc) }
  scope :for_person, ->(person) { where(person: person) }
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

  def self.average_days_between_check_ins(person)
    check_ins = for_person(person).order(:check_in_started_on)
    return nil if check_ins.count < 2
    
    total_days = 0
    check_ins.each_cons(2) do |first, second|
      total_days += (second.check_in_started_on - first.check_in_started_on).to_i
    end
    
    total_days.to_f / (check_ins.count - 1)
  end

  # Find the associated assignment tenure for this check-in
  def assignment_tenure
    @assignment_tenure ||= AssignmentTenure.most_recent_for(person, assignment)
  end

  # Find or create open check-in for a person and assignment
  def self.find_or_create_open_for(person, assignment)
    tenure = AssignmentTenure.most_recent_for(person, assignment)
    return nil unless tenure
    
    # Find existing open check-in for this person/assignment
    open_check_in = where(person: person, assignment: assignment).open.first
    return open_check_in if open_check_in
    
    # Create new open check-in if none exists
    create!(
      person: person,
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

  def complete_employee_side!
    update!(employee_completed_at: Time.current)
  end

  def complete_manager_side!
    update!(manager_completed_at: Time.current)
  end

  def uncomplete_employee_side!
    update!(employee_completed_at: nil)
  end

  def uncomplete_manager_side!
    update!(manager_completed_at: nil)
  end

  def finalize_check_in!(final_rating: nil)
    raise ArgumentError, "Final rating is required for check-in finalization" if final_rating.blank?
    
    update!(
      official_check_in_completed_at: Time.current,
      official_rating: final_rating
    )
  end

  private

  def only_one_open_check_in_per_person_assignment
    return unless open? # Only validate for open check-ins
    
    existing_open = AssignmentCheckIn
      .where(person: person, assignment: assignment)
      .open
      .where.not(id: id)
    
    if existing_open.exists?
      errors.add(:base, "Only one open check-in allowed per person per assignment")
    end
  end
end
