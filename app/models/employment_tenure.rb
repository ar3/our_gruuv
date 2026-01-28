class EmploymentTenure < ApplicationRecord
  belongs_to :teammate
  belongs_to :company, class_name: 'Organization'
  belongs_to :position
  belongs_to :manager_teammate, class_name: 'CompanyTeammate', optional: true
  belongs_to :seat, optional: true
  
  has_many :position_check_ins, dependent: :nullify

  validates :started_at, presence: true
  validates :ended_at, comparison: { greater_than: :started_at }, allow_nil: true
  validates :employment_type, inclusion: { 
    in: %w[full_time part_time contract contractor intern temporary consultant freelance], 
    allow_blank: true 
  }
  validate :no_overlapping_active_tenures_for_same_teammate_and_company
  validate :seat_title_matches_position, if: :seat

  POSITION_RATINGS = {
    -3 => { key: :monitoring_pip, emoji: '🔴', label: 'Performance Improvement Plan', description: 'Monitoring during PIP' },
    -2 => { key: :monitoring_after_written_warning, emoji: '⭕️', label: 'Written Warning', description: 'Monitoring after written warning' },
    -1 => { key: :monitoring_after_verbal_warning, emoji: '🟠', label: 'Verbal Warning', description: 'Monitoring after verbal warning' },
     1 => { key: :actively_coaching, emoji: '🟡', label: 'Developing', description: 'Meets some expectations, but improvement and consistency are needed in specific areas' },
     2 => { key: :actively_trusting, emoji: '🔵', label: 'Accomplished', description: 'Consistently meets and sometimes exceeds expectations' },
     3 => { key: :looking_to_reward, emoji: '🟢', label: 'Exceptional', description: 'Consistently exceeds expectations, going above and beyond what is required' }
  }.freeze


  validates :official_position_rating, inclusion: { in: POSITION_RATINGS.keys }, allow_nil: true

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

  def position_rating_display
    return 'Not Rated' if official_position_rating.nil?
    data = POSITION_RATINGS[official_position_rating]
    "#{data[:emoji]} #{data[:label]}"
  end

  def position_rating_emoji
    POSITION_RATINGS.dig(official_position_rating, :emoji)
  end

  def position_rating_label
    POSITION_RATINGS.dig(official_position_rating, :label)
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

  def seat_title_matches_position
    return unless seat && position
    
    # Compare IDs to avoid object identity issues
    unless seat.title_id == position.title_id
      errors.add(:seat, "must match the title of the selected position")
    end
  end

  def no_overlapping_active_tenures_for_same_teammate_and_company
    return unless teammate_id && company_id && started_at

    # Skip validation when closing a tenure (setting ended_at)
    # We should always allow closing a tenure, even if other active tenures exist
    # The validation should only prevent creating/keeping multiple active tenures
    if persisted? && ended_at.present? && ended_at_changed?
      return
    end

    # Only validate if this tenure is or will be active (ended_at is nil)
    # This prevents creating multiple active tenures simultaneously
    return if ended_at.present?

    # The rule is simple: only ONE active tenure per teammate/company at a time
    # Check if there are any other active tenures (regardless of dates)
    # If this is a new record (not persisted), we need to check for any active tenures
    # If this is an update, we've already excluded this record with where.not(id: id)
    other_active_tenures = EmploymentTenure
      .where(teammate: teammate, company: company)
      .where.not(id: id) # Exclude current record if updating
      .where(ended_at: nil) # Only check active tenures

    if other_active_tenures.exists?
      errors.add(:base, 'Cannot have overlapping active employment tenures for the same teammate and company')
    end
  end
end
