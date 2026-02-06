class AssignmentOutcome < ApplicationRecord
  # Associations
  belongs_to :assignment
  
  # Validations
  validates :description, presence: true
  validates :assignment, presence: true
  validates :outcome_type, inclusion: { in: %w[quantitative sentiment], allow_blank: false }
  validates :management_relationship_filter, inclusion: { in: %w[direct_employee direct_manager no_relationship] }, allow_blank: true
  validates :team_relationship_filter, inclusion: { in: %w[same_team different_team] }, allow_blank: true
  validates :consumer_assignment_filter, inclusion: { in: %w[active_consumer not_consumer] }, allow_blank: true
  
  # Constants
  TYPES = %w[quantitative sentiment].freeze
  
  # Scopes
  scope :ordered, -> { order(:created_at) }
  
  # Instance methods
  def display_name
    description
  end

  # True if any of the "additional configuration" fields are set (progress report URL, who to ask filters).
  def has_additional_configuration?
    progress_report_url.present? ||
      management_relationship_filter.present? ||
      team_relationship_filter.present? ||
      consumer_assignment_filter.present?
  end

  def additional_configuration_badge_label
    has_additional_configuration? ? "Modify/View add'l config" : "Add add'l config"
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
