class UploadEvent < ApplicationRecord
  belongs_to :creator, class_name: 'Person'
  belongs_to :initiator, class_name: 'Person'
  belongs_to :organization

  enum :status, {
    preview: 'preview',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed'
  }

  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :file_content, presence: true
  validates :filename, presence: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :previewable, -> { where(status: %w[preview failed]) }
  scope :processable, -> { where(status: 'preview') }
  scope :completed_or_failed, -> { where(status: %w[completed failed]) }

  # Instance methods
  def preview?
    status == 'preview'
  end

  def processing?
    status == 'processing'
  end

  def completed?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  def can_process?
    preview? || failed?
  end

  def can_destroy?
    preview? || failed?
  end

  def mark_as_processing!
    update!(status: 'processing', attempted_at: Time.current)
  end

  def mark_as_completed!(results)
    update!(
      status: 'completed',
      results: results,
      attempted_at: Time.current
    )
  end

  def mark_as_failed!(error_message)
    update!(
      status: 'failed',
      results: { error: error_message },
      attempted_at: Time.current
    )
  end

  def success_count
    return 0 unless results&.dig('successes')
    results['successes'].count
  end

  def failure_count
    return 0 unless results&.dig('failures')
    results['failures'].count
  end

  def processed?
    completed? || failed?
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

  # Format success details for display with links
  def success_details_for(success_record)
    return 'Unknown record' unless success_record.is_a?(Hash)
    
    case success_record['type']
    when 'person'
      name = success_record['name'] || 'Unknown person'
      if success_record['id']
        "<a href='/people/#{success_record['id']}'>#{name}</a>"
      else
        name
      end
    when 'assignment'
      title = success_record['title'] || 'Unknown assignment'
      if success_record['id']
        "<a href='/assignments/#{success_record['id']}'>#{title}</a>"
      else
        title
      end
    when 'assignment_tenure'
      person_name = success_record['person_name'] || 'Unknown person'
      assignment_title = success_record['assignment_title'] || 'Unknown assignment'
      "#{person_name} - #{assignment_title}"
    when 'assignment_check_in'
      person_name = success_record['person_name'] || 'Unknown person'
      assignment_title = success_record['assignment_title'] || 'Unknown assignment'
      "#{person_name} - #{assignment_title}"
    when 'external_reference'
      assignment_title = success_record['assignment_title'] || 'Unknown assignment'
      url = success_record['url'] || 'No URL'
      "#{assignment_title} (#{url})"
    else
      'Unknown type'
    end
  end
end
