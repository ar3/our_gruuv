class Organization < ApplicationRecord
  # Single Table Inheritance
  self.inheritance_column = 'type'
  
  # Associations
  belongs_to :parent, class_name: 'Organization', optional: true
  has_many :children, class_name: 'Organization', foreign_key: 'parent_id'
  has_many :huddles, dependent: :destroy
  has_many :huddle_playbooks, dependent: :destroy
  has_many :assignments, foreign_key: 'company_id', dependent: :destroy
  has_one :slack_configuration, dependent: :destroy
  has_many :third_party_objects, dependent: :destroy
  has_many :third_party_object_associations, as: :associatable, dependent: :destroy
  
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
end 