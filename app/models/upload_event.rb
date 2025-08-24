class UploadEvent < ApplicationRecord
  # Associations
  belongs_to :creator, class_name: 'Person'
  belongs_to :initiator, class_name: 'Person'
  
  # Enums
  enum :status, {
    preview: 'preview',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed'
  }
  
  # Validations
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :file_content, presence: true
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :completed_or_failed, -> { where(status: [:completed, :failed]) }
  
  # Instance methods
  def preview?
    status == 'preview'
  end
  
  def processed?
    %w[completed failed].include?(status)
  end
  
  def can_process?
    preview? && preview_actions.present?
  end
  
  def success_count
    return 0 unless results&.dig('successes')
    results['successes'].count
  end
  
  def failure_count
    return 0 unless results&.dig('failures')
    results['failures'].count
  end
  
  def total_operations
    success_count + failure_count
  end
  
  def has_failures?
    failure_count > 0
  end
  
  def all_successful?
    processed? && failure_count == 0
  end
  
  def mark_as_processing!
    update!(status: 'processing', attempted_at: Time.current)
  end
  
  def mark_as_completed!(results_data)
    update!(status: 'completed', results: results_data, attempted_at: Time.current)
  end
  
  def mark_as_failed!(error_message)
    update!(
      status: 'failed', 
      results: { error: error_message }, 
      attempted_at: Time.current
    )
  end
end
