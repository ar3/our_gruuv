class Assignment < ApplicationRecord
  # Associations
  belongs_to :company, class_name: 'Organization'
  has_many :assignment_outcomes, dependent: :destroy
  
  # Validations
  validates :title, presence: true
  validates :tagline, presence: true
  validates :company, presence: true
  validates :published_source_url, format: { with: URI::regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true
  validates :draft_source_url, format: { with: URI::regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true
  
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
