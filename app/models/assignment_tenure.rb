class AssignmentTenure < ApplicationRecord
  belongs_to :teammate
  belongs_to :assignment
  has_many :assignment_check_ins, dependent: :destroy

  validates :started_at, presence: true
  validates :ended_at, comparison: { greater_than_or_equal_to: :started_at }, allow_nil: true
  validates :anticipated_energy_percentage, 
            inclusion: { in: 0..100 }, 
            allow_nil: true
  validate :no_overlapping_active_tenures_for_same_teammate_and_assignment

  scope :active, -> { where(ended_at: nil) }
  scope :inactive, -> { where.not(ended_at: nil) }
  scope :for_teammate, ->(teammate) { where(teammate: teammate) }
  scope :for_assignment, ->(assignment) { where(assignment_id: assignment.id) }
  scope :most_recent_for_teammate_and_assignment, ->(teammate, assignment) { 
    for_teammate(teammate).for_assignment(assignment).order(started_at: :desc).limit(1) 
  }

  def active?
    ended_at.nil?
  end

  def inactive?
    !active?
  end

  def self.most_recent_for(teammate, assignment)
    most_recent_for_teammate_and_assignment(teammate, assignment).first
  end

  private

  def no_overlapping_active_tenures_for_same_teammate_and_assignment
    return unless teammate_id && assignment_id && started_at

    # Find tenures that would overlap with this one
    # A tenure overlaps if:
    # 1. It's active (ended_at IS NULL) OR it ends after our start date
    # 2. AND it starts before our end date (or before today if we're active)
    # Only check for overlaps with active tenures
    end_date_for_comparison = ended_at || Date.current + 1.day
    overlapping_tenures = AssignmentTenure
      .where(teammate_id: teammate.id, assignment_id: assignment.id)
      .where.not(id: id) # Exclude current record if updating
      .where('ended_at IS NULL') # Only check active tenures
      .where('started_at < ?', end_date_for_comparison)

    if overlapping_tenures.exists?
      errors.add(:base, 'Cannot have overlapping active assignment tenures for the same teammate and assignment')
    end
  end
end
