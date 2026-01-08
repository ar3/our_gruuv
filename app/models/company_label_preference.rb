class CompanyLabelPreference < ApplicationRecord
  belongs_to :company, class_name: 'Organization'

  validates :company_id, presence: true
  validates :label_key, presence: true
  validates :label_key, uniqueness: { scope: :company_id }
  validate :company_must_be_company_type

  scope :for_company, ->(company) { where(company: company) }
  scope :for_key, ->(key) { where(label_key: key) }

  private

  def company_must_be_company_type
    return unless company_id.present?
    
    company_record = Organization.find_by(id: company_id)
    if company_record && !company_record.company?
      errors.add(:company, 'must be a Company type organization')
    end
  end
end
