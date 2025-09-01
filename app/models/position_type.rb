class PositionType < ApplicationRecord
  # Associations
  belongs_to :organization
  belongs_to :position_major_level
  has_many :positions, dependent: :destroy
  has_many :seats, dependent: :destroy
  has_one :published_external_reference, -> { where(reference_type: 'published') }, 
          class_name: 'ExternalReference', as: :referable, dependent: :destroy
  has_one :draft_external_reference, -> { where(reference_type: 'draft') }, 
          class_name: 'ExternalReference', as: :referable, dependent: :destroy
  
  # Validations
  validates :organization, presence: true
  validates :position_major_level, presence: true
  validates :external_title, presence: true
  validates :external_title, uniqueness: { scope: [:organization_id, :position_major_level_id] }
  validate :organization_must_be_company_or_department
  
  # Scopes
  scope :ordered, -> { order(:external_title) }
  
  # Instance methods
  def display_name
    external_title
  end
  
  # External reference convenience methods
  def published_url
    published_external_reference&.url
  end
  
  def draft_url
    draft_external_reference&.url
  end
  
  private
  
  def organization_must_be_company_or_department
    return unless organization
    
    unless organization.company? || organization.department?
      errors.add(:organization, 'must be a company or department')
    end
  end
end 