class HuddleParticipant < ApplicationRecord
  # Associations
  belongs_to :huddle
  belongs_to :person
  
  # Validations
  validates :role, presence: true
  validates :person_id, uniqueness: { scope: :huddle_id }
  
  # Constants
  ROLES = %w[facilitator scribe active passive].freeze
  
  # Validations
  validates :role, inclusion: { in: ROLES }
  
  # Scopes
  scope :facilitators, -> { where(role: 'facilitator') }
  scope :scribes, -> { where(role: 'scribe') }
  scope :active_participants, -> { where(role: 'active') }
  scope :passive_participants, -> { where(role: 'passive') }
  
  # Instance methods
  def facilitator?
    role == 'facilitator'
  end
  
  def scribe?
    role == 'scribe'
  end
  
  def active?
    role == 'active'
  end
  
  def passive?
    role == 'passive'
  end
end 