class ExternalReference < ApplicationRecord
  # Associations
  belongs_to :referable, polymorphic: true
  
  # Validations
  validates :url, format: { with: URI::regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true
  validates :reference_type, presence: true
  validates :referable, presence: true
  
  # Scopes
  scope :published, -> { where(reference_type: 'published') }
  scope :draft, -> { where(reference_type: 'draft') }
  
  # Instance methods
  def display_name
    "#{referable&.display_name} (#{reference_type})"
  end
  
  def sync_needed?
    last_synced_at.nil? || last_synced_at < 1.hour.ago
  end
end 