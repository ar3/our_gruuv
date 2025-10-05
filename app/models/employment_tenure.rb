class EmploymentTenure < ApplicationRecord
  belongs_to :teammate
  belongs_to :company, class_name: 'Organization'
  belongs_to :position
  belongs_to :manager, class_name: 'Person', optional: true
  belongs_to :seat, optional: true

  validates :started_at, presence: true
  validates :ended_at, comparison: { greater_than: :started_at }, allow_nil: true
  validates :employment_type, inclusion: { 
    in: %w[full_time part_time contract contractor intern temporary consultant freelance], 
    allow_blank: true 
  }
  validate :no_overlapping_active_tenures_for_same_teammate_and_company
  validate :seat_position_type_matches_position, if: :seat

  # Callbacks
  after_create :update_seat_state_to_filled
  after_update :update_seat_state_on_employment_end, if: :saved_change_to_ended_at?

  scope :active, -> { where(ended_at: nil) }
  scope :inactive, -> { where.not(ended_at: nil) }
  scope :for_teammate, ->(teammate) { where(teammate: teammate) }
  scope :for_company, ->(company) { where(company: company) }
  scope :most_recent_for_teammate_and_company, ->(teammate, company) { 
    for_teammate(teammate).for_company(company).order(started_at: :desc).limit(1) 
  }

  def active?
    ended_at.nil?
  end

  def inactive?
    !active?
  end

  def self.most_recent_for(teammate, company)
    most_recent_for_teammate_and_company(teammate, company).first
  end

  private

  def update_seat_state_to_filled
    return unless seat && seat.state == 'open'
    
    seat.update!(state: 'filled')
  end

  def update_seat_state_on_employment_end
    return unless seat && ended_at.present?
    
    # Check if this is the only active employment tenure for this seat
    other_active_tenures = EmploymentTenure.where(seat: seat, ended_at: nil).where.not(id: id)
    
    if other_active_tenures.empty?
      seat.update!(state: 'open')
    end
  end

  def seat_position_type_matches_position
    return unless seat && position
    
    unless seat.position_type == position.position_type
      errors.add(:seat, "must match the position type of the selected position")
    end
  end

  def no_overlapping_active_tenures_for_same_teammate_and_company
    return unless teammate_id && company_id && started_at

    overlapping_tenures = EmploymentTenure
      .where(teammate: teammate, company: company)
      .where.not(id: id) # Exclude current record if updating
      .where('(ended_at IS NULL OR ended_at > ?) AND started_at < ?', started_at, ended_at || Date.current)

    if overlapping_tenures.exists?
      errors.add(:base, 'Cannot have overlapping active employment tenures for the same teammate and company')
    end
  end
end
