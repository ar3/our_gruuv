class Assignment < ApplicationRecord
  include PgSearch::Model
  include ModelSemanticVersionable
  
  # Associations
  belongs_to :company, class_name: 'Organization'
  belongs_to :department, class_name: 'Organization', optional: true
  has_many :assignment_outcomes, dependent: :destroy
  has_many :position_assignments, dependent: :destroy
  has_many :positions, through: :position_assignments
  has_many :assignment_tenures, dependent: :destroy
  has_many :assignment_abilities, dependent: :destroy
  has_many :abilities, through: :assignment_abilities
  has_many :observation_ratings, as: :rateable, dependent: :destroy
  has_many :observations, through: :observation_ratings
  has_many :comments, as: :commentable, dependent: :destroy
  has_one :published_external_reference, -> { where(reference_type: 'published') }, 
          class_name: 'ExternalReference', as: :referable, dependent: :destroy
  has_one :draft_external_reference, -> { where(reference_type: 'draft') }, 
          class_name: 'ExternalReference', as: :referable, dependent: :destroy
  has_many :supplier_supply_relationships, class_name: 'AssignmentSupplyRelationship', foreign_key: 'supplier_assignment_id', dependent: :destroy
  has_many :consumer_supply_relationships, class_name: 'AssignmentSupplyRelationship', foreign_key: 'consumer_assignment_id', dependent: :destroy
  has_many :consumer_assignments, through: :supplier_supply_relationships, source: :consumer_assignment
  has_many :supplier_assignments, through: :consumer_supply_relationships, source: :supplier_assignment
  
  # Validations
  validates :title, presence: true, uniqueness: { scope: :company_id }
  validates :tagline, presence: true
  validates :company, presence: true
  validate :department_must_belong_to_company
  
  # Virtual attribute for outcomes textarea
  attr_accessor :outcomes_textarea
  
  # Scopes
  scope :ordered, -> { order(:title) }

  # Finder method that handles both id and id-name formats
  def self.find_by_param(param)
    # If param is just a number, use it as id
    return find(param) if param.to_s.match?(/\A\d+\z/)
    
    # Otherwise, extract id from id-name format
    id = param.to_s.split('-').first
    find(id)
  end
  
  # Instance methods
  def display_name
    "#{title} v#{semantic_version}"
  end
  
  def to_s
    hierarchy = [company&.name].compact
    hierarchy += department_ancestry_names if department.present?
    hierarchy << display_name
    hierarchy.join(' > ')
  end

  def name
    title
  end

  def to_param
    "#{id}-#{title.parameterize}"
  end
  
  def company_name
    company&.display_name
  end

  # Calculate number of changes based on PaperTrail versions
  def changes_count
    # PaperTrail creates a version on create and on each update
    # Subtract 1 to get the number of changes (not counting the initial creation)
    [versions.count - 1, 0].max
  end

  # Ability-related methods
  def required_abilities
    assignment_abilities.by_milestone_level.includes(:ability)
  end

  def required_abilities_count
    assignment_abilities.count
  end

  def has_ability_requirements?
    assignment_abilities.exists?
  end

  def highest_milestone_for_ability(ability)
    assignment_abilities.where(ability: ability).maximum(:milestone_level)
  end

  def add_ability_requirement(ability, milestone_level)
    assignment_abilities.create!(ability: ability, milestone_level: milestone_level)
  end

  def remove_ability_requirement(ability)
    assignment_abilities.where(ability: ability).destroy_all
  end

  # Outcomes convenience method
  def outcomes
    assignment_outcomes.ordered
  end


  
  # External reference convenience methods
  def published_url
    published_external_reference&.url
  end
  
  def draft_url
    draft_external_reference&.url
  end
  
  def create_outcomes_from_textarea(text)
    processor = AssignmentOutcomesProcessor.new(self, text)
    processor.process
  end
  
  # pg_search configuration
  pg_search_scope :search_by_full_text,
    against: {
      title: 'A',
      tagline: 'B',
      required_activities: 'B',
      handbook: 'B'
    },
    using: {
      tsearch: { prefix: true, any_word: true }
    }
  
  multisearchable against: [:title, :tagline, :required_activities, :handbook]
  
  private
  
  def department_ancestry_names
    return [] unless department
    node = department
    path = []
    while node && node != company
      path.unshift(node.name)
      node = node.parent
    end
    path
  end

  def department_must_belong_to_company
    return unless department && company
    
    # Check if department's root company matches the assignment's company
    # or if department is in the company's descendants
    department_root = department.root_company
    company_descendants = company.self_and_descendants.map(&:id)
    
    unless department_root == company || company_descendants.include?(department.id)
      Rails.logger.error "❌❌ Department validation failed"
      Rails.logger.error "❌❌ Department ID: #{department.id}, Department name: #{department.name}"
      Rails.logger.error "❌❌ Department root company: #{department_root&.id} (#{department_root&.name})"
      Rails.logger.error "❌❌ Assignment company ID: #{company.id}, Company name: #{company.name}"
      Rails.logger.error "❌❌ Company descendants IDs: #{company_descendants.inspect}"
      errors.add(:department, 'must belong to the same company')
    end
  end
end
