class Organization < ApplicationRecord
  # Single Table Inheritance
  self.inheritance_column = 'type'
  
  # Associations
  belongs_to :parent, class_name: 'Organization', optional: true
  has_many :children, class_name: 'Organization', foreign_key: 'parent_id'
  has_many :huddles, dependent: :destroy
  has_many :huddle_playbooks, dependent: :destroy
  has_one :slack_configuration, dependent: :destroy
  
  # Validations
  validates :name, presence: true
  validates :type, presence: true
  
  # Scopes
  scope :companies, -> { where(type: 'Company') }
  scope :teams, -> { where(type: 'Team') }
  
  # Instance methods
  def company?
    type == 'Company'
  end
  
  def team?
    type == 'Team'
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
end 