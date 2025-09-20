class InterestSubmission < ApplicationRecord
  belongs_to :person
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_source_page, ->(page) { where(source_page: page) }
  
  # Instance methods
  def display_name
    "#{source_page.humanize} Interest - #{person.display_name}"
  end
  
  def has_content?
    thing_interested_in.present? || why_interested.present? || current_solution.present?
  end
end
