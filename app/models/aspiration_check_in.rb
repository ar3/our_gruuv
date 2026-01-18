class AspirationCheckIn < ApplicationRecord
  include CheckInBehavior
  
  belongs_to :teammate
  belongs_to :aspiration
  belongs_to :manager_completed_by_teammate, class_name: 'CompanyTeammate', optional: true
  
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

  # Validations
  validates :check_in_started_on, presence: true
  validates :employee_rating, inclusion: { in: employee_ratings.keys }, allow_nil: true
  validates :manager_rating, inclusion: { in: manager_ratings.keys }, allow_nil: true
  validates :official_rating, inclusion: { in: official_ratings.keys }, allow_nil: true
  validates :manager_completed_by_teammate, presence: true, if: :manager_completed?
  validates :finalized_by_teammate, presence: true, if: :officially_completed?
  
  # Custom validation to prevent multiple open check-ins per teammate per aspiration
  validate :only_one_open_check_in_per_teammate_aspiration

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

  def previous_finalized_check_in
    @previous_finalized_check_in ||= AspirationCheckIn
      .where(teammate: teammate, aspiration: aspiration)
      .closed
      .order(:official_check_in_completed_at)
      .last
  end

  def previous_check_in_summary
    return nil unless previous_finalized_check_in
    
    previous = previous_finalized_check_in
    "last finalized on #{previous.official_check_in_completed_at.to_date} with rating of #{previous.official_rating&.humanize}"
  end

  # Find or create open check-in for a teammate and aspiration
  def self.find_or_create_open_for(teammate, aspiration)
    open_check_in = where(teammate: teammate, aspiration: aspiration).open.first
    return open_check_in if open_check_in
    
    create!(
      teammate: teammate,
      aspiration: aspiration,
      check_in_started_on: Date.current
    )
  end
  
  # Find the latest finalized check-in for a teammate and aspiration
  def self.latest_finalized_for(teammate, aspiration)
    where(teammate: teammate, aspiration: aspiration)
      .closed
      .order(official_check_in_completed_at: :desc)
      .first
  end
  
  private
  
  def only_one_open_check_in_per_teammate_aspiration
    return unless open?
    
    existing_open = AspirationCheckIn
      .where(teammate: teammate, aspiration: aspiration)
      .open
      .where.not(id: id)
    
    if existing_open.exists?
      errors.add(:base, "Only one open aspiration check-in allowed per teammate per aspiration")
    end
  end
end
