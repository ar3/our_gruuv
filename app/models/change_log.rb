class ChangeLog < ApplicationRecord
  # Enums
  enum :change_type, {
    new_value: 'new_value',
    major_enhancement: 'major_enhancement',
    minor_enhancement: 'minor_enhancement',
    bug_fix: 'bug_fix'
  }

  # Scopes
  scope :recent, -> { order(launched_on: :desc, created_at: :desc) }
  scope :by_change_type, ->(type) { where(change_type: type) }
  scope :in_past_90_days, -> { where('launched_on >= ?', 90.days.ago.to_date) }

  # Validations
  validates :launched_on, presence: true
  validates :change_type, presence: true
  validates :description, presence: true
end

