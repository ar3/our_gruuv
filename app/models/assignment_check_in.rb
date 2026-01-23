class AssignmentCheckIn < ApplicationRecord
  include CheckInBehavior
  
  belongs_to :assignment
  belongs_to :manager_completed_by_teammate, class_name: 'CompanyTeammate', optional: true
  belongs_to :maap_snapshot, optional: true

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
  validates :manager_completed_by_teammate, presence: true, if: :manager_completed?
  validates :finalized_by_teammate, presence: true, if: :officially_completed?
  
  # Custom validation to prevent multiple open check-ins per teammate per assignment
  validate :only_one_open_check_in_per_teammate_assignment

  # Virtual attribute for form handling
  attr_accessor :status

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

  def previous_finalized_check_in
    @previous_finalized_check_in ||= AssignmentCheckIn
      .where(teammate: teammate, assignment: assignment)
      .closed
      .order(:official_check_in_completed_at)
      .last
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

  # Find the latest finalized check-in for a teammate and assignment
  def self.latest_finalized_for(teammate, assignment)
    where(teammate: teammate, assignment: assignment)
      .closed
      .order(official_check_in_completed_at: :desc)
      .first
  end

  # Find the associated assignment tenure for this check-in
  # Prefers active tenure if one exists, otherwise returns most recent tenure
  def assignment_tenure
    return @assignment_tenure if @assignment_tenure
    
    # First, try to find an active tenure
    active_tenure = AssignmentTenure.where(teammate: teammate, assignment: assignment).active.first
    
    if active_tenure
      @assignment_tenure = active_tenure
    else
      # Fall back to most recent tenure if no active one exists
      @assignment_tenure = AssignmentTenure.most_recent_for(teammate, assignment)
    end
    
    @assignment_tenure
  end

  # Find or create open check-in for a teammate and assignment
  def self.find_or_create_open_for(teammate, assignment)
    tenure = AssignmentTenure.most_recent_for(teammate, assignment)
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

  def employee_started?
    actual_energy_percentage.present? || employee_personal_alignment.present? || employee_rating.present? || employee_private_notes.present?
  end

  def manager_started?
    manager_rating.present? || manager_private_notes.present?
  end


  def finalize_check_in!(final_rating: nil, finalized_by: nil)
    raise ArgumentError, "Final rating is required for check-in finalization" if final_rating.blank?
    
    update!(
      official_check_in_completed_at: Time.current,
      official_rating: final_rating,
      finalized_by_teammate: finalized_by
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
