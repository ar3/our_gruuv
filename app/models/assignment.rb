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
  has_one :published_external_reference, -> { where(reference_type: 'published') }, 
          class_name: 'ExternalReference', as: :referable, dependent: :destroy
  has_one :draft_external_reference, -> { where(reference_type: 'draft') }, 
          class_name: 'ExternalReference', as: :referable, dependent: :destroy
  
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
  
  def name
    title
  end

  def to_param
    "#{id}-#{title.parameterize}"
  end
  
  def company_name
    company&.display_name
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
    return if text.blank?
    
    # Split by newlines, strip whitespace, and filter out empty lines
    descriptions = text.split("\n").map(&:strip).reject(&:blank?)
    
    descriptions.each do |description|
      # Determine type based on content
      type = if description.downcase.match?(/agree:|agrees:/)
        'sentiment'
      else
        'quantitative'
      end
      
      assignment_outcomes.create!(description: description, outcome_type: type)
    end
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
  
  def department_must_belong_to_company
    return unless department && company
    
    unless department.parent == company
      errors.add(:department, 'must belong to the same company')
    end
  end
end
