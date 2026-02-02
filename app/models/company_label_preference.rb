class CompanyLabelPreference < ApplicationRecord
  belongs_to :company, class_name: 'Organization'

  validates :company_id, presence: true
  validates :label_key, presence: true
  validates :label_key, uniqueness: { scope: :company_id }

  scope :for_company, ->(company) { where(company: company) }
  scope :for_key, ->(key) { where(label_key: key) }
end
