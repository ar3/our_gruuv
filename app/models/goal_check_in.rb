class GoalCheckIn < ApplicationRecord
  has_paper_trail
  
  belongs_to :goal
  belongs_to :confidence_reporter, class_name: 'Person'
  
  # Validations
  validates :confidence_percentage, inclusion: { in: 0..100 }, allow_nil: true
  validates :check_in_week_start, presence: true
  validates :goal_id, uniqueness: { scope: :check_in_week_start, message: "already has a check-in for this week" }
  validate :check_in_week_start_must_be_monday
  validate :at_least_one_field_present
  
  # Scopes
  scope :for_week, ->(week_start) { where(check_in_week_start: week_start) }
  scope :recent, -> { order(check_in_week_start: :desc) }
  scope :for_goal, ->(goal) { where(goal: goal) }
  
  # Instance methods
  def week_range
    check_in_week_start..check_in_week_start.end_of_week(:sunday)
  end
  
  def week_display
    "#{check_in_week_start.strftime('%b %d')} - #{check_in_week_start.end_of_week(:sunday).strftime('%b %d, %Y')}"
  end
  
  private
  
  def check_in_week_start_must_be_monday
    return unless check_in_week_start.present?
    
    unless check_in_week_start.monday?
      errors.add(:check_in_week_start, "must be a Monday")
    end
  end
  
  def at_least_one_field_present
    if confidence_percentage.nil? && confidence_reason.blank?
      errors.add(:base, "Either confidence percentage or reason must be provided")
    end
  end
end


