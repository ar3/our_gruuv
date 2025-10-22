class EnmPartnership < ApplicationRecord
  # Validations
  validates :code, presence: true, uniqueness: true, length: { is: 8 }, format: { with: /\A[A-Z0-9]+\z/ }
  validates :assessment_codes, presence: true
  validate :assessment_codes_not_empty
  validates :relationship_type, inclusion: { in: %w[M S H P] }, allow_nil: true
  
  # Methods
  def assessments
    EnmAssessment.where(code: assessment_codes)
  end
  
  def add_assessment_code(new_code)
    self.assessment_codes = (assessment_codes + [new_code]).uniq
  end
  
  def remove_assessment_code(code_to_remove)
    self.assessment_codes = assessment_codes - [code_to_remove]
  end
  
  def shareable_url
    "/enm/partnerships/#{code}"
  end
  
  def relationship_description
    case relationship_type
    when 'M' then 'Monogamy / Security-Focused'
    when 'S' then 'Swing / Exploratory Fun'
    when 'H' then 'Hybrid / Bridging Worlds'
    when 'P' then 'Polysecure / Emotionally Networked'
    else 'Unknown'
    end
  end
  
  private
  
  def assessment_codes_not_empty
    errors.add(:assessment_codes, "can't be empty") if assessment_codes.blank?
  end
end




