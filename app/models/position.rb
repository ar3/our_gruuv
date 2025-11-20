class Position < ApplicationRecord
  include PgSearch::Model
  include SemanticVersionable
  has_paper_trail
  
  # Associations
  belongs_to :position_type
  belongs_to :position_level
  has_many :position_assignments, dependent: :destroy
  has_many :assignments, through: :position_assignments
  has_one :published_external_reference, -> { where(reference_type: 'published') }, 
          class_name: 'ExternalReference', as: :referable, dependent: :destroy
  has_one :draft_external_reference, -> { where(reference_type: 'draft') }, 
          class_name: 'ExternalReference', as: :referable, dependent: :destroy
  
  # Validations
  validates :position_type, presence: true
  validates :position_level, presence: true
  validates :position_level, uniqueness: { scope: :position_type_id }
  validates :position_level, inclusion: { in: ->(position) { position.position_type&.position_major_level&.position_levels || [] } }
  
  # Callbacks
  before_save :normalize_eligibility_requirements_summary
  
  # Scopes
  scope :ordered, -> { joins(:position_type, :position_level).order('position_types.external_title, position_levels.level') }
  scope :for_company, ->(company) { joins(position_type: :organization).where(organizations: { id: company.id }) }

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
    base_name = "#{position_type.external_title} - #{position_level.level}"
    "#{base_name} v#{semantic_version}"
  end

  def to_param
    "#{id}-#{display_name.parameterize}"
  end
  
  def company
    position_type.organization
  end
  
  def required_assignments
    position_assignments.where(assignment_type: 'required').includes(:assignment)
  end
  
  def suggested_assignments
    position_assignments.where(assignment_type: 'suggested').includes(:assignment)
  end
  
  def required_assignments_count
    position_assignments.where(assignment_type: 'required').count
  end
  
  def suggested_assignments_count
    position_assignments.where(assignment_type: 'suggested').count
  end
  
  # External reference convenience methods
  def published_url
    published_external_reference&.url
  end
  
  def draft_url
    draft_external_reference&.url
  end

  
  # pg_search configuration
  pg_search_scope :search_by_full_text,
    associated_against: {
      position_type: [:external_title],
      position_level: [:level]
    },
    using: {
      tsearch: { prefix: true, any_word: true }
    }
  
  multisearchable against: [],
    associated_against: {
      position_type: [:external_title],
      position_level: [:level]
    }
  
  private
  
  def normalize_eligibility_requirements_summary
    self.eligibility_requirements_summary = nil unless eligibility_requirements_summary.present?
  end
end 