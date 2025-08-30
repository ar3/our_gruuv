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

  # Scopes
  scope :recent, -> { order(check_in_started_on: :desc) }
  scope :for_person, ->(person) { where(person: person) }
  scope :for_assignment, ->(assignment) { where(assignment: assignment) }
  scope :open, -> { where(check_in_ended_on: nil) }
  scope :closed, -> { where.not(check_in_ended_on: nil) }

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
    check_in_ended_on.nil?
  end

  def closed?
    !open?
  end

  def close!(ended_on: Date.current)
    update!(check_in_ended_on: ended_on)
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
end
