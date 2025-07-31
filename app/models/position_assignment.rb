class PositionAssignment < ApplicationRecord
  # Associations
  belongs_to :position
  belongs_to :assignment
  
  # Validations
  validates :position, presence: true
  validates :assignment, presence: true
  validates :assignment_type, presence: true, inclusion: { in: %w[required suggested] }
  validates :assignment, uniqueness: { scope: :position }
  
  # Scopes
  scope :required, -> { where(assignment_type: 'required') }
  scope :suggested, -> { where(assignment_type: 'suggested') }
  
  # Instance methods
  def display_name
    "#{assignment.title} (#{assignment_type})"
  end
end 