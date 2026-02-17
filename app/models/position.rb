class Position < ApplicationRecord
  include PgSearch::Model
  include ModelSemanticVersionable
  
  # Associations
  belongs_to :title
  belongs_to :position_level
  has_many :position_assignments, dependent: :destroy
  has_many :assignments, through: :position_assignments
  has_many :position_abilities, dependent: :destroy
  has_many :abilities, through: :position_abilities
  has_many :comments, as: :commentable, dependent: :destroy
  has_one :published_external_reference, -> { where(reference_type: 'published') }, 
          class_name: 'ExternalReference', as: :referable, dependent: :destroy
  has_one :draft_external_reference, -> { where(reference_type: 'draft') }, 
          class_name: 'ExternalReference', as: :referable, dependent: :destroy
  
  # Validations
  validates :title, presence: true
  validates :position_level, presence: true
  validates :position_level, uniqueness: { scope: :title_id }
  validates :position_level, inclusion: { in: ->(position) { position.title&.position_major_level&.position_levels || [] } }
  
  # Callbacks
  before_save :normalize_eligibility_requirements_summary
  
  # Scopes
  scope :ordered, -> { joins(:title, :position_level).order('titles.external_title, position_levels.level') }
  scope :for_company, ->(company) { joins(:title).where(titles: { company_id: company.id }) }

  # Finder method that handles both id and id-name formats
  def self.find_by_param(param)
    # If param is just a number, use it as id
    return find(param) if param.to_s.match?(/\A\d+\z/)
    
    # Otherwise, extract id from id-name format
    id = param.to_s.split('-').first
    find(id)
  end
  
  # Instance methods
  def display_name_with_version
    "#{display_name} v#{semantic_version}"
  end

  def display_name
    "#{title.external_title} - #{position_level.level}"
  end

  def to_s
    display_name
  end

  def to_param
    "#{id}-#{display_name.parameterize}"
  end
  
  def company
    title.company
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

  # Summary for job description and public views: title summary first, then position summary.
  def combined_summary
    parts = [title&.position_summary, position_summary].compact_blank
    return nil if parts.empty?
    parts.join("\n\n")
  end

  # pg_search configuration
  pg_search_scope :search_by_full_text,
    associated_against: {
      title: [:external_title],
      position_level: [:level]
    },
    using: {
      tsearch: { prefix: true, any_word: true }
    }
  
  multisearchable against: [],
    associated_against: {
      title: [:external_title],
      position_level: [:level]
    }
  
  private
  
  def normalize_eligibility_requirements_summary
    self.eligibility_requirements_summary = nil unless eligibility_requirements_summary.present?
  end
end 