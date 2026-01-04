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

  def display_name_with_major_level
    "#{position_major_level.major_level} #{external_title}"
  end

  # MAAP Maturity methods
  def maap_maturity_phase
    PositionTypeMaturityService.calculate_phase(self)
  end

  def maap_maturity_phase_display
    "Phase #{maap_maturity_phase}"
  end

  def maap_maturity_next_steps
    PositionTypeMaturityService.next_steps_message(self)
  end

  def maap_maturity_phase_status
    PositionTypeMaturityService.phase_status(self)
  end

  def maap_maturity_phase_health_status
    PositionTypeMaturityService.phase_health_status(self)
  end

  def maap_maturity_phase_health_reason(phase)
    PositionTypeMaturityService.phase_health_reason(self, phase)
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