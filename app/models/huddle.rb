class Huddle < ApplicationRecord
  # Associations
  belongs_to :organization
  has_many :huddle_participants, dependent: :destroy
  has_many :participants, through: :huddle_participants, source: :person
  has_many :huddle_feedbacks, dependent: :destroy
  
  # Validations
  validates :started_at, presence: true
  validate :unique_organization_per_day
  
  # Scopes
  scope :active, -> { where('started_at >= ?', 1.day.ago) }
  scope :recent, -> { order(started_at: :desc) }
  
  # Instance methods
  def display_name
    base_name = "#{organization.display_name} - #{started_at.strftime('%B %d, %Y')}"
    huddle_alias.present? ? "#{base_name} - #{huddle_alias}" : base_name
  end
  
  def slug
    "#{organization.name.parameterize}_#{started_at.strftime('%Y-%m-%d')}"
  end
  
  def closed?
    # Huddle closes at the end of the day UTC after first feedback is submitted
    return false if huddle_feedbacks.empty?
    started_at.to_date < Date.current
  end
  
  def department_head
    organization.department_head
  end
  
  def nat_20_score
    return nil if huddle_feedbacks.empty?
    
    total_score = huddle_feedbacks.sum do |feedback|
      feedback.informed_rating + feedback.connected_rating + 
      feedback.goals_rating + feedback.valuable_rating
    end
    
    (total_score.to_f / huddle_feedbacks.count).round(1)
  end
  
  def feedback_anonymous?
    huddle_feedbacks.any?(&:anonymous)
  end
  
  private
  
  def unique_organization_per_day
    return unless organization_id && started_at
    
    # Check for existing huddles on the same date (not time range)
    existing_huddle = Huddle.where(
      organization_id: organization_id
    ).where(
      "DATE(started_at) = DATE(?)", started_at
    ).where.not(id: id).first
    
    if existing_huddle
      errors.add(:base, "A huddle for this organization already exists today")
      errors.add(:existing_huddle_id, existing_huddle.id)
    end
  end
end 