class Assignment < ApplicationRecord
  # Associations
  belongs_to :company, class_name: 'Organization'
  has_many :assignment_outcomes, dependent: :destroy
  
  # Validations
  validates :title, presence: true
  validates :tagline, presence: true
  validates :company, presence: true
  
  # Scopes
  scope :ordered, -> { order(:title) }
  
  # Instance methods
  def display_name
    title
  end
  
  def company_name
    company&.display_name
  end
end
