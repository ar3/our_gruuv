class Organization < ApplicationRecord
  include PgSearch::Model

  # Associations
  has_many :teams, foreign_key: :company_id, dependent: :destroy
  has_many :departments, foreign_key: :company_id, dependent: :destroy
  has_many :assignments, foreign_key: 'company_id', dependent: :destroy
  has_many :abilities, foreign_key: 'company_id', dependent: :destroy
  has_many :aspirations, foreign_key: 'company_id', dependent: :destroy
  has_many :prompt_templates, foreign_key: 'company_id', dependent: :destroy
  has_many :titles, foreign_key: 'company_id', dependent: :destroy
  has_many :seats, through: :titles
  has_many :seats_as_team, class_name: 'Seat', foreign_key: 'team_id', dependent: :nullify
  has_one :slack_configuration, dependent: :destroy
  has_many :third_party_objects, dependent: :destroy
  has_many :third_party_object_associations, as: :associatable, dependent: :destroy
  has_many :teammates, dependent: :destroy
  has_many :bulk_sync_events, dependent: :destroy
  has_many :upload_events, class_name: 'BulkSyncEvent', dependent: :destroy # Backward compatibility alias
  has_many :bulk_downloads, foreign_key: 'company_id', dependent: :destroy
  has_many :observations, foreign_key: :company_id, dependent: :destroy

  # Company-specific associations (formerly in Company STI subclass)
  has_one :huddle_review_notification_channel_association,
          -> { where(association_type: 'huddle_review_notification_channel') },
          class_name: 'ThirdPartyObjectAssociation',
          as: :associatable
  has_one :huddle_review_notification_channel,
          through: :huddle_review_notification_channel_association,
          source: :third_party_object

  has_one :maap_object_comment_channel_association,
          -> { where(association_type: 'maap_object_comment_channel') },
          class_name: 'ThirdPartyObjectAssociation',
          as: :associatable
  has_one :maap_object_comment_channel,
          through: :maap_object_comment_channel_association,
          source: :third_party_object

  has_many :company_label_preferences, foreign_key: 'company_id', dependent: :destroy

  # Validations
  validates :name, presence: true

  # Scopes
  scope :ordered, -> { order(:name) }
  scope :active, -> { where(deleted_at: nil) }
  scope :archived, -> { where.not(deleted_at: nil) }

  # Finder method that handles both id and id-name formats
  def self.find_by_param(param)
    # If param is just a number, use it as id
    return find(param) if param.to_s.match?(/\A\d+\z/)
    
    # Otherwise, extract id from id-name format
    id = param.to_s.split('-').first
    find(id)
  end
  
  # Find organization by Slack workspace ID
  def self.find_by_slack_workspace_id(workspace_id)
    slack_config = SlackConfiguration.find_by(workspace_id: workspace_id)
    slack_config&.organization
  end

  # Instance methods
  # All organizations are now effectively "companies" (no STI)
  def company?
    true
  end

  def department?
    # This is always false for Organization since Department is its own model
    false
  end

  def root_company
    # Organizations no longer have parent hierarchy - each Organization is its own root
    self
  end
  
  def department_head
    # Climb up the hierarchy to find a Department organization with a manager
    # For now, we'll implement this when we add the manager concept
    nil
  end
  
  def display_name
    name
  end

  def to_param
    "#{id}-#{name.parameterize}"
  end
  
  def slack_configured?
    calculated_slack_config&.configured?
  end
  
  def calculated_slack_config
    slack_configuration || root_company&.slack_configuration
  end
  
  # Slack group association methods
  def slack_group_association
    third_party_object_associations.where(association_type: 'slack_group').first
  end
  
  def slack_group
    slack_group_association&.third_party_object
  end
  
  def slack_group_id
    slack_group&.third_party_id
  end
  
  def slack_group_id=(group_id)
    if group_id.present?
      # Use root company's third_party_objects since departments/teams don't have their own
      root_company_obj = root_company || self
      group = root_company_obj.third_party_objects.where(third_party_source: 'slack', third_party_object_type: 'group').find_by(third_party_id: group_id)
      if group
        # Remove existing association
        slack_group_association&.destroy
        
        # Create new association
        third_party_object_associations.create!(
          third_party_object: group,
          association_type: 'slack_group'
        )
      end
    else
      slack_group_association&.destroy
    end
  end

  # Kudos channel association methods
  def kudos_channel_association
    third_party_object_associations.where(association_type: 'observation_kudos_channel').first
  end
  
  def kudos_channel
    kudos_channel_association&.third_party_object
  end
  
  def kudos_channel_id
    kudos_channel&.third_party_id
  end
  
  def kudos_channel_id=(channel_id)
    if channel_id.present?
      # Use root company's third_party_objects since departments/teams don't have their own
      root_company_obj = root_company || self
      channel = root_company_obj.third_party_objects.slack_channels.find_by(third_party_id: channel_id)
      if channel
        # Remove existing association
        kudos_channel_association&.destroy
        
        # Create new association
        third_party_object_associations.create!(
          third_party_object: channel,
          association_type: 'observation_kudos_channel'
        )
      end
    else
      kudos_channel_association&.destroy
    end
  end
  
  def self_and_descendants
    # For Company, this returns just the company since departments are separate
    [self]
  end
  
  def descendants
    # For Company, descendants are empty since departments are now separate
    []
  end
  
  def ancestry_depth
    # Organizations no longer have parent hierarchy
    0
  end
  
  def employees
    # People employed at this organization
    Person.joins(teammates: :employment_tenures).where(employment_tenures: { company: self })
  end
  
  def positions
    # Positions within this organization (via titles linked to this company)
    Position.joins(:title).where(titles: { company_id: id })
  end

  def titles_count
    titles.count
  end

  def seats_count
    seats.count
  end

  def huddle_participants
    # People who have participated in huddles within this organization's teams
    Person
      .joins(teammates: { huddle_participants: { huddle: :team } })
      .where(teams: { company_id: id })
      .distinct(:id).order(:last_name)
  end

  def huddles
    Huddle.joins(:team).where(teams: { company_id: id })
  end

  def just_huddle_participants
    # People who participated in huddles but are not active employees
    huddle_participants.where.not(id: employees.select(:id))
  end

  def all_assignments_including_descendants
    # With departments separated, assignments are directly linked to company
    Assignment.where(company: self)
  end

  # Milestone-related methods
  def recent_milestones_count(days_back: 90)
    TeammateMilestone.joins(:ability)
                   .where(abilities: { company_id: id })
                   .where(attained_at: days_back.days.ago..Time.current)
                   .count
  end

  def abilities_count
    abilities.count
  end

  def teammate_milestones_for_person(person)
    teammate = person.teammates.find_by(organization: self)
    return TeammateMilestone.none unless teammate
    
    teammate.teammate_milestones.joins(:ability)
            .where(abilities: { company_id: id })
  end

  def descendants_count
    # With departments separated, this returns count of departments for the company
    departments.active.count
  end

  def teams_with_recent_huddles(weeks_back: 6)
    start_date = weeks_back.weeks.ago

    Team.joins(:huddles)
        .where(company_id: id)
        .where(huddles: { started_at: start_date..Time.current })
        .distinct
        .includes(:company)
  end
  
  # Permission helper methods
  def can_manage_employment?(person)
    Teammate.can_manage_employment_in_hierarchy?(person, self)
  end
  
  def can_create_employment?(person)
    return true if person.og_admin?
    teammate = person.teammates.find_by(organization: self)
    teammate&.can_create_employment? || false
  end
  
  # Company-specific methods (formerly in Company STI subclass)
  def huddle_review_notification_channel_id
    huddle_review_notification_channel&.third_party_id
  end

  def huddle_review_notification_channel_id=(channel_id)
    if channel_id.present?
      channel = third_party_objects.slack_channels.find_by(third_party_id: channel_id)
      if channel
        # Remove existing association
        huddle_review_notification_channel_association&.destroy

        # Create new association
        third_party_object_associations.create!(
          third_party_object: channel,
          association_type: 'huddle_review_notification_channel'
        )
      end
    else
      huddle_review_notification_channel_association&.destroy
    end
  end

  def maap_object_comment_channel_id
    maap_object_comment_channel&.third_party_id
  end

  def maap_object_comment_channel_id=(channel_id)
    if channel_id.present?
      channel = third_party_objects.slack_channels.find_by(third_party_id: channel_id)
      if channel
        # Remove existing association
        maap_object_comment_channel_association&.destroy

        # Create new association
        third_party_object_associations.create!(
          third_party_object: channel,
          association_type: 'maap_object_comment_channel'
        )
      end
    else
      maap_object_comment_channel_association&.destroy
    end
  end

  def label_for(key, default = nil)
    preference = company_label_preferences.find_by(label_key: key.to_s)
    if preference&.label_value.present?
      preference.label_value
    elsif default.present?
      default
    else
      key.to_s.titleize
    end
  end

  # pg_search configuration
  pg_search_scope :search_by_full_text,
    against: {
      name: 'A'
    },
    using: {
      tsearch: { prefix: true, any_word: true }
    }

  multisearchable against: [:name]

  # Archiving methods (soft delete - NO default_scope)
  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def archived?
    deleted_at.present?
  end
end
