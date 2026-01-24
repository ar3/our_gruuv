class BulkDownload < ApplicationRecord
  # Associations
  belongs_to :company, class_name: 'Organization'
  belongs_to :downloaded_by, class_name: 'CompanyTeammate'

  # Validations
  validates :company, presence: true
  validates :downloaded_by, presence: true
  validates :download_type, presence: true
  validates :s3_key, presence: true
  validates :s3_url, presence: true
  validates :filename, presence: true

  # Scopes
  scope :by_type, ->(type) { where(download_type: type) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_organization, ->(org) { where(company: org) }
end
