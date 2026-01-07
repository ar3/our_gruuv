class TeammateMilestone < ApplicationRecord
  # Associations
  belongs_to :teammate
  belongs_to :ability
  belongs_to :certifying_teammate, class_name: 'CompanyTeammate'
  belongs_to :published_by_teammate, class_name: 'CompanyTeammate', optional: true
  has_one :observable_moment, as: :momentable, dependent: :destroy

  # Validations
  validates :teammate, presence: true
  validates :ability, presence: true
  validates :milestone_level, presence: true, 
            numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :certifying_teammate, presence: true
  validates :attained_at, presence: true
  validates :milestone_level, uniqueness: { scope: [:teammate_id, :ability_id], 
                                          message: 'has already been taken for this teammate and ability' }

  # Scopes
  scope :by_milestone_level, -> { order(:milestone_level) }
  scope :for_teammate, ->(teammate) { where(teammate: teammate) }
  scope :for_ability, ->(ability) { where(ability: ability) }
  scope :recent, -> { order(attained_at: :desc) }
  scope :published, -> { where.not(published_at: nil) }
  scope :public_profile_published, -> { where.not(public_profile_published_at: nil) }
  scope :unpublished, -> { where(published_at: nil) }

  # Instance methods
  def milestone_level_display
    "Milestone #{milestone_level}"
  end

  def attainment_display
    "#{ability.name} - #{milestone_level_display} (attained #{attained_at.strftime('%B %d, %Y')})"
  end

  def certifier_display
    certifying_teammate.person.display_name
  end

  def published?
    published_at.present?
  end

  def public_profile_published?
    public_profile_published_at.present?
  end

  def eligible_viewers
    viewers = []
    
    # Add the employee (receiver)
    viewers << {
      person: teammate.person,
      role: 'Employee (Milestone Recipient)'
    }
    
    # Add managers in the hierarchy
    managers = ManagerialHierarchyQuery.new(
      person: teammate.person,
      organization: teammate.organization
    ).call
    
    managers.each do |manager|
      viewers << {
        person: Person.find(manager[:person_id]),
        role: "Manager (Level #{manager[:level]})"
      }
    end
    
    # Add people with manage_employment permission in the organization
    employment_managers = teammate.organization.teammates
                                  .where(can_manage_employment: true, last_terminated_at: nil)
                                  .includes(:person)
    
    employment_managers.each do |manager_teammate|
      # Don't duplicate if already in managers list
      next if managers.any? { |m| m[:person_id] == manager_teammate.person_id }
      next if manager_teammate.person_id == teammate.person_id
      
      viewers << {
        person: manager_teammate.person,
        role: 'Has Manage Employment Permission'
      }
    end
    
    viewers.uniq { |v| v[:person].id }
  end
end
