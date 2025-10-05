class HuddleFeedback < ApplicationRecord
  # Associations
  belongs_to :huddle
  belongs_to :teammate
  
  # Validations
  validates :informed_rating, :connected_rating, :goals_rating, :valuable_rating,
            presence: true, inclusion: { in: 0..5 }
  validates :personal_conflict_style, :team_conflict_style,
            inclusion: { in: %w[Collaborative Competing Compromising Accommodating Avoiding], allow_blank: true }
  validates :teammate_id, uniqueness: { scope: :huddle_id }
  
  # Constants
  CONFLICT_STYLES = %w[Collaborative Competing Compromising Accommodating Avoiding].freeze
  
  # Scopes
  scope :anonymous, -> { where(anonymous: true) }
  scope :named, -> { where(anonymous: false) }
  def display_personal_conflict_style
    personal_conflict_style.present? ? personal_conflict_style : 'N/A'
  end

  def display_team_conflict_style
    team_conflict_style.present? ? team_conflict_style : 'N/A'
  end
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
    anonymous ? 'Anonymous' : teammate.person.full_name
  end
end 