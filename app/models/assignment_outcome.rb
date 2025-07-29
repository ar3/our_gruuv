class AssignmentOutcome < ApplicationRecord
  # Associations
  belongs_to :assignment
  
  # Validations
  validates :description, presence: true
  validates :assignment, presence: true
  validates :outcome_type, inclusion: { in: %w[quantitative sentiment], allow_blank: false }
  
  # Constants
  TYPES = %w[quantitative sentiment].freeze
  
  # Scopes
  scope :ordered, -> { order(:created_at) }
  
  # Instance methods
  def display_name
    description
  end
end
