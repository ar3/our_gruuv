class HuddleFeedback < ApplicationRecord
  # Associations
  belongs_to :huddle
  belongs_to :person
  
  # Validations
  validates :informed_rating, :connected_rating, :goals_rating, :valuable_rating,
            presence: true, inclusion: { in: 0..5 }
  validates :personal_conflict_style, :team_conflict_style,
            inclusion: { in: %w[Collaborative Competing Compromising Accommodating Avoiding Other], allow_blank: true }
  validates :person_id, uniqueness: { scope: :huddle_id }
  
  # Constants
  CONFLICT_STYLES = %w[Collaborative Competing Compromising Accommodating Avoiding Other].freeze
  
  # Scopes
  scope :anonymous, -> { where(anonymous: true) }
  scope :named, -> { where(anonymous: false) }
  
  # Instance methods
  def nat_20_score
    informed_rating + connected_rating + goals_rating + valuable_rating
  end
  
  def perfect_nat_20?
    nat_20_score == 20
  end
  
  def has_private_feedback?
    private_department_head.present? || private_facilitator.present?
  end
  
  def display_name
    anonymous ? 'Anonymous' : person.name
  end
end 