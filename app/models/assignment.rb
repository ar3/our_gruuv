class Assignment < ApplicationRecord
  # Associations
  belongs_to :company, class_name: 'Organization'
  has_many :assignment_outcomes, dependent: :destroy
  
  # Validations
  validates :title, presence: true
  validates :tagline, presence: true
  validates :company, presence: true
  validates :published_source_url, format: { with: URI::regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true
  validates :draft_source_url, format: { with: URI::regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true
  
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
