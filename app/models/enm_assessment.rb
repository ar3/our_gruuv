class EnmAssessment < ApplicationRecord
  # Validations
  validates :code, presence: true, uniqueness: true, length: { is: 8 }, format: { with: /\A[A-Z0-9]+\z/ }
  validates :completed_phase, presence: true, inclusion: { in: 1..3 }
  validates :macro_category, inclusion: { in: %w[M S P H] }, allow_nil: true
  validates :readiness, inclusion: { in: %w[C P A] }, allow_nil: true
  validates :style, inclusion: { in: %w[K H R F S C] }, allow_nil: true
  
  # Scopes
  scope :completed, -> { where(completed_phase: 3) }
  scope :by_macro_category, ->(category) { where(macro_category: category) }
  
  # Associations
  has_many :enm_partnerships, -> { where("assessment_codes @> ?", [code].to_json) }, 
           foreign_key: :id, primary_key: :id, class_name: 'EnmPartnership'
  
  # Methods
  def completed?
    completed_phase == 3
  end
  
  def shareable_url
    "/enm/assessments/#{code}"
  end
  
  def typology_description
    Enm::AssessmentCalculatorService.new.get_typology_description(full_code)
  end
  
  def partnerships
    EnmPartnership.where("assessment_codes @> ?", [code].to_json)
  end
end
