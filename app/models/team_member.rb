class TeamMember < ApplicationRecord
  # Associations
  belongs_to :team
  belongs_to :company_teammate, class_name: 'Teammate'

  # Delegations
  delegate :person, to: :company_teammate
  delegate :full_name, :email, :preferred_first_then_last_display_name, to: :person, prefix: false

  # Validations
  validates :team, presence: true
  validates :company_teammate, presence: true
  validates :company_teammate_id, uniqueness: { scope: :team_id, message: 'is already a member of this team' }

  # Scopes
  scope :for_team, ->(team) { where(team: team) }
  scope :for_teammate, ->(teammate) { where(company_teammate: teammate) }
end
