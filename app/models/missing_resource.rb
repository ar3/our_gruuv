class MissingResource < ApplicationRecord
  has_many :missing_resource_requests, dependent: :destroy

  validates :path, presence: true, uniqueness: true
  validates :request_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :most_requested, -> { order(request_count: :desc, last_seen_at: :desc) }
  scope :recent, -> { order(last_seen_at: :desc) }
  scope :with_suggestions, -> { where.not(suggested_redirect_path: nil) }

  def increment_request_count!
    increment!(:request_count)
    touch(:last_seen_at)
  end

  def update_last_seen!
    touch(:last_seen_at)
  end
end

