class AssignmentOutcome < ApplicationRecord
  # Associations
  belongs_to :assignment
  
  # Validations
  validates :description, presence: true
  validates :assignment, presence: true
  validates :outcome_type, inclusion: { in: %w[quantitative sentiment], allow_blank: false }
  validates :management_relationship_filter, inclusion: { in: %w[direct_employee direct_manager no_relationship] }, allow_nil: true
  validates :team_relationship_filter, inclusion: { in: %w[same_team different_team] }, allow_nil: true
  validates :consumer_assignment_filter, inclusion: { in: %w[active_consumer not_consumer] }, allow_nil: true
  
  # Constants
  TYPES = %w[quantitative sentiment].freeze
  
  # Scopes
  scope :ordered, -> { order(:created_at) }
  
  # Instance methods
  def display_name
    description
  end

  # Extract content between quotes for qualitative outcomes
  # Returns the first quoted string found, or nil if none found
  def extract_quoted_content
    return nil if description.blank?
    
    # Match content between single or double quotes
    match = description.match(/["']([^"']+)["']/)
    match ? match[1] : nil
  end
end
