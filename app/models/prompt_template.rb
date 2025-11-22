class PromptTemplate < ApplicationRecord
  # Associations
  belongs_to :company, class_name: 'Organization'
  has_many :prompt_questions, dependent: :destroy
  has_many :prompts, dependent: :destroy

  # Callbacks
  before_destroy :check_for_prompts, prepend: true

  # Validations
  validates :title, presence: true
  validates :company, presence: true
  validate :only_one_primary_per_company
  validate :only_one_secondary_per_company
  validate :only_one_tertiary_per_company

  # Scopes
  scope :available, -> { where.not(available_at: nil).where('available_at <= ?', Date.current) }
  scope :primary, -> { where(is_primary: true) }
  scope :secondary, -> { where(is_secondary: true) }
  scope :tertiary, -> { where(is_tertiary: true) }
  scope :ordered, -> { order(:title) }

  # Instance methods
  def available?
    available_at.present? && available_at <= Date.current
  end

  private

  def check_for_prompts
    if prompts.exists?
      errors.add(:base, 'Cannot delete prompt template that has prompts')
      throw(:abort)
    end
  end

  def only_one_primary_per_company
    return unless is_primary?
    return unless company_id.present?

    existing = PromptTemplate.where(company_id: company_id, is_primary: true)
    existing = existing.where.not(id: id) if persisted?
    
    if existing.exists?
      errors.add(:is_primary, 'can only have one primary template per company')
    end
  end

  def only_one_secondary_per_company
    return unless is_secondary?
    return unless company_id.present?

    existing = PromptTemplate.where(company_id: company_id, is_secondary: true)
    existing = existing.where.not(id: id) if persisted?
    
    if existing.exists?
      errors.add(:is_secondary, 'can only have one secondary template per company')
    end
  end

  def only_one_tertiary_per_company
    return unless is_tertiary?
    return unless company_id.present?

    existing = PromptTemplate.where(company_id: company_id, is_tertiary: true)
    existing = existing.where.not(id: id) if persisted?
    
    if existing.exists?
      errors.add(:is_tertiary, 'can only have one tertiary template per company')
    end
  end
end

