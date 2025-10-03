class HuddleParticipant < ApplicationRecord
  # Associations
  belongs_to :huddle
  belongs_to :person
  belongs_to :teammate, optional: true
  
  # Constants
  ROLES = HuddleConstants::ROLES
  ROLE_LABELS = HuddleConstants::ROLE_LABELS
  
  # Validations
  validates :role, presence: true, inclusion: { in: ROLES }
  validates :person_id, uniqueness: { scope: :huddle_id }
  
  # Scopes
  scope :facilitators, -> { where(role: 'facilitator') }
  scope :active_participants, -> { where(role: 'active') }
  
  # Instance methods
  def role_label
    ROLE_LABELS[role] || role.titleize
  end
  
  def facilitator?
    role == 'facilitator'
  end
  
  def active_participant?
    role == 'active'
  end
end 