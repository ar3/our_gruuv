class IncomingWebhook < ApplicationRecord
  belongs_to :organization, optional: true
  belongs_to :resultable, polymorphic: true, optional: true

  enum :status, {
    unprocessed: 'unprocessed',
    processing: 'processing',
    processed: 'processed',
    failed: 'failed'
  }

  validates :provider, presence: true
  validates :event_type, presence: true
  validates :status, presence: true

  scope :unprocessed, -> { where(status: :unprocessed) }
  scope :processing, -> { where(status: :processing) }
  scope :processed, -> { where(status: :processed) }
  scope :failed, -> { where(status: :failed) }

  def mark_processing!
    update!(status: :processing)
  end

  def mark_processed!
    update!(status: :processed, processed_at: Time.current)
  end

  def mark_failed!(error_message = nil)
    update!(status: :failed, error_message: error_message, processed_at: Time.current)
  end
end

