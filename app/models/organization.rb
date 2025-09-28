class Organization < ApplicationRecord
  # Single Table Inheritance
  self.inheritance_column = 'type'
  
  # Associations
  belongs_to :parent, class_name: 'Organization', optional: true
  has_many :children, class_name: 'Organization', foreign_key: 'parent_id'
  has_many :huddle_playbooks, dependent: :destroy
  has_many :huddles, through: :huddle_playbooks
  has_many :assignments, foreign_key: 'company_id', dependent: :destroy
  has_many :abilities, dependent: :destroy
  has_many :aspirations, dependent: :destroy
  has_many :position_types, dependent: :destroy
  has_many :seats, through: :position_types
  has_one :slack_configuration, dependent: :destroy
  has_many :third_party_objects, dependent: :destroy
  has_many :third_party_object_associations, as: :associatable, dependent: :destroy
  has_many :person_organization_accesses, dependent: :destroy
  has_many :upload_events, dependent: :destroy
  
  # Validations
  validates :name, presence: true
  validates :type, presence: true
  
  # Scopes
  scope :companies, -> { where(type: 'Company') }
  scope :teams, -> { where(type: 'Team') }
  scope :departments, -> { where(type: 'Department') }
  scope :ordered, -> { order(:name) }
  
  # Instance methods
  def company?
    type == 'Company'
  end
  
  def team?
    type == 'Team'
  end
  
  def department?
    type == 'Department'
  end
  
  def root_company
    return self if company? && parent.nil?
    return parent.root_company if parent
    nil
  end
  
  def department_head
    # Climb up the hierarchy to find a Department organization with a manager
    # For now, we'll implement this when we add the manager concept
    nil
  end
  
  def display_name
    if parent
      "#{parent.display_name} > #{name}"
    else
      name
    end
  end
  
  def slack_configured?
    calculated_slack_config&.configured?
  end
  
  def calculated_slack_config
    slack_configuration || root_company&.slack_configuration
  end
  
  def self_and_descendants
    [self] + descendants
  end
  
  def descendants
    children.flat_map { |child| [child] + child.descendants }
  end
  
  def ancestry_depth
    return 0 if parent.nil?
    parent.ancestry_depth + 1
  end
  
  def employees
    # People employed at this organization
    Person.joins(:employment_tenures).where(employment_tenures: { company: self })
  end
  
  def positions
    # Positions within this organization
    Position.joins(:position_type).where(position_types: { organization: self })
  end

  def position_types_count
    position_types.count
  end

  def seats_count
    seats.count
  end

  def huddle_participants
    # People who have participated in huddles within this organization and all child organizations
    Person
      .joins(huddle_participants: { huddle: :huddle_playbook })
      .where(huddle_playbooks: { organization_id: self_and_descendants })
      .distinct(:id).order(:last_name)
  end

  def just_huddle_participants
    # People who participated in huddles but are not active employees
    huddle_participants.where.not(id: employees.select(:id))
  end

  def all_assignments_including_descendants
    Assignment.where(company: self_and_descendants)
  end

  def recent_huddle_playbooks(include_descendants: false, weeks_back: 6)
    start_date = weeks_back.weeks.ago
    organizations_to_search = include_descendants ? self_and_descendants : [self]
    
    HuddlePlaybook.joins(:huddles)
                  .where(organization: organizations_to_search)
                  .where(huddles: { started_at: start_date..Time.current })
                  .distinct
                  .includes(:organization)
  end
  
  # Permission helper methods
  def can_manage_employment?(person)
    PersonOrganizationAccess.can_manage_employment_in_hierarchy?(person, self)
  end
  
  def can_create_employment?(person)
    PersonOrganizationAccess.can_create_employment?(person, self)
  end
end 