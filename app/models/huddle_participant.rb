class HuddleParticipant < ApplicationRecord
  # Associations
  belongs_to :huddle
  belongs_to :company_teammate, class_name: 'CompanyTeammate', foreign_key: 'teammate_id'
  alias_method :teammate, :company_teammate
  alias_method :teammate=, :company_teammate=

  # Constants
  ROLES = HuddleConstants::ROLES
  ROLE_LABELS = HuddleConstants::ROLE_LABELS
  
  # Validations
  validates :role, presence: true, inclusion: { in: ROLES }
  validates :teammate_id, uniqueness: { scope: :huddle_id }
  
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