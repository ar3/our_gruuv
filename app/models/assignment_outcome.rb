class AssignmentOutcome < ApplicationRecord
  # Associations
  belongs_to :assignment
  
  # Validations
  validates :description, presence: true
  validates :assignment, presence: true
  
  # Scopes
  scope :ordered, -> { order(:created_at) }
  
  # Instance methods
  def display_name
    description
  end
end
