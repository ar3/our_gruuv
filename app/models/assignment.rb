class Assignment < ApplicationRecord
  # Associations
  belongs_to :company, class_name: 'Organization'
  has_many :assignment_outcomes, dependent: :destroy
  has_many :position_assignments, dependent: :destroy
  has_many :positions, through: :position_assignments
  has_many :assignment_tenures, dependent: :destroy
  has_one :published_external_reference, -> { where(reference_type: 'published') }, 
          class_name: 'ExternalReference', as: :referable, dependent: :destroy
  has_one :draft_external_reference, -> { where(reference_type: 'draft') }, 
          class_name: 'ExternalReference', as: :referable, dependent: :destroy
  
  # Validations
  validates :title, presence: true, uniqueness: { scope: :company_id }
  validates :tagline, presence: true
  validates :company, presence: true
  
  # Virtual attribute for outcomes textarea
  attr_accessor :outcomes_textarea
  
  # Scopes
  scope :ordered, -> { order(:title) }
  
  # Instance methods
  def display_name
    title
  end
  
  def company_name
    company&.display_name
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
end
