class AssignmentCheckIn < ApplicationRecord
  belongs_to :assignment_tenure
  has_one :person, through: :assignment_tenure
  has_one :assignment, through: :assignment_tenure

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
  validates :check_in_date, presence: true
  validates :actual_energy_percentage, 
            inclusion: { in: 0..100 }, 
            allow_nil: true
  validates :employee_rating, inclusion: { in: employee_ratings.keys }, allow_nil: true
  validates :manager_rating, inclusion: { in: manager_ratings.keys }, allow_nil: true
  validates :official_rating, inclusion: { in: official_ratings.keys }, allow_nil: true
  validates :employee_personal_alignment, inclusion: { in: employee_personal_alignments.keys }, allow_nil: true

  # Scopes
  scope :recent, -> { order(check_in_date: :desc) }
  scope :for_person, ->(person) { joins(:assignment_tenure).where(assignment_tenures: { person: person }) }
  scope :for_assignment, ->(assignment) { joins(:assignment_tenure).where(assignment_tenures: { assignment: assignment }) }

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
    return false unless actual_energy_percentage && assignment_tenure.anticipated_energy_percentage
    
    difference = (actual_energy_percentage - assignment_tenure.anticipated_energy_percentage).abs
    difference > 20 # Flag if difference is more than 20%
  end

  def days_since_tenure_start
    return nil unless assignment_tenure.started_at
    
    (check_in_date - assignment_tenure.started_at.to_date).to_i
  end

  def self.average_days_between_check_ins(person)
    check_ins = for_person(person).order(:check_in_date)
    return nil if check_ins.count < 2
    
    total_days = 0
    check_ins.each_cons(2) do |first, second|
      total_days += (second.check_in_date - first.check_in_date).to_i
    end
    
    total_days.to_f / (check_ins.count - 1)
  end
end
