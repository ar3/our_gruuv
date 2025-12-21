class BulkSyncEvent < ApplicationRecord
  belongs_to :creator, class_name: 'Person'
  belongs_to :initiator, class_name: 'Person'
  belongs_to :organization

  # Tell Pundit to use BulkSyncEventPolicy for all STI subclasses
  def self.policy_class
    BulkSyncEventPolicy
  end

  # Handle STI type mapping for backward compatibility
  def self.find_sti_class(type_name)
    case type_name
    when 'UploadAssignmentCheckins', 'BulkSyncEvent::UploadAssignmentCheckins'
      BulkSyncEvent::UploadAssignmentCheckins
    when 'UploadEmployees', 'BulkSyncEvent::UploadEmployees'
      BulkSyncEvent::UploadEmployees
    when 'UploadAssignmentsAndAbilities', 'BulkSyncEvent::UploadAssignmentsAndAbilities'
      BulkSyncEvent::UploadAssignmentsAndAbilities
    when 'UploadEvent::UploadAssignmentCheckins'
      BulkSyncEvent::UploadAssignmentCheckins
    when 'UploadEvent::UploadEmployees'
      BulkSyncEvent::UploadEmployees
    else
      super
    end
  end

  def self.sti_name
    # Always store the fully qualified class name
    name
  end

  enum :status, {
    preview: 'preview',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed'
  }

  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :source_data, presence: true
  
  # Conditional validations based on source type
  validate :validate_source_contents_for_file_uploads
  validate :validate_filename_for_file_uploads

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

  # Helper methods for unified access
  def file_content
    # Backward compatibility alias
    source_contents
  end

  def file_content=(value)
    # Backward compatibility alias
    self.source_contents = value
  end

  def source_type
    source_data&.dig('type') || 'unknown'
  end

  def source_info
    case source_type
    when 'file_upload'
      "File: #{source_data['filename']} (#{source_data['file_size']} bytes)"
    when 'slack_sync'
      "Slack: #{source_data['workspace_name']} (#{source_data['total_users_fetched']} users)"
    when 'database_sync'
      "Database: #{source_data['sync_type']} (#{source_data['total_records_found']} records)"
    else
      'Unknown source'
    end
  end

  def has_source_contents?
    source_contents.present?
  end

  def raw_slack_data
    return nil unless source_type == 'slack_sync' && source_contents.present?
    JSON.parse(source_contents) rescue nil
  end

  # Abstract methods to be implemented by subclasses
  def validate_file_type(file)
    raise NotImplementedError, 'Subclasses must implement validate_file_type'
  end

  def process_file_for_preview
    raise NotImplementedError, 'Subclasses must implement process_file_for_preview'
  end

  def process_upload_in_background
    raise NotImplementedError, 'Subclasses must implement process_upload_in_background'
  end

  def display_name
    raise NotImplementedError, 'Subclasses must implement display_name'
  end

  def file_extension
    raise NotImplementedError, 'Subclasses must implement file_extension'
  end

  # Format success details for display with links
  def success_details_for(success_record)
    return 'Unknown record' unless success_record.is_a?(Hash)
    
    routes = Rails.application.routes.url_helpers
    org = organization
    
    case success_record['type']
    when 'person', 'unassigned_employee'
      name = success_record['name'] || 'Unknown person'
      if success_record['id']
        "<a href='/people/#{success_record['id']}'>#{name}</a>"
      else
        name
      end
    when 'assignment'
      title = success_record['title'] || 'Unknown assignment'
      if success_record['id']
        "<a href='#{routes.organization_assignment_path(org, success_record['id'])}' class='text-decoration-none'>#{title}</a>"
      else
        title
      end
    when 'ability'
      name = success_record['name'] || 'Unknown ability'
      if success_record['id']
        "<a href='#{routes.organization_ability_path(org, success_record['id'])}' class='text-decoration-none'>#{name}</a>"
      else
        name
      end
    when 'assignment_ability'
      assignment_title = success_record['assignment_title'] || 'Unknown assignment'
      ability_name = success_record['ability_name'] || 'Unknown ability'
      assignment_link = if success_record['assignment_id']
        "<a href='#{routes.organization_assignment_path(org, success_record['assignment_id'])}' class='text-decoration-none'>#{assignment_title}</a>"
      else
        assignment_title
      end
      ability_link = if success_record['ability_id']
        "<a href='#{routes.organization_ability_path(org, success_record['ability_id'])}' class='text-decoration-none'>#{ability_name}</a>"
      else
        ability_name
      end
      "#{assignment_link} - #{ability_link}"
    when 'position_assignment'
      assignment_title = success_record['assignment_title'] || 'Unknown assignment'
      position_title = success_record['position_title'] || 'Unknown position'
      position_link = if success_record['position_id']
        "<a href='#{routes.organization_position_path(org, success_record['position_id'])}' class='text-decoration-none'>#{position_title}</a>"
      else
        position_title
      end
      assignment_link = if success_record['assignment_id']
        "<a href='#{routes.organization_assignment_path(org, success_record['assignment_id'])}' class='text-decoration-none'>#{assignment_title}</a>"
      else
        assignment_title
      end
      "#{position_link} - #{assignment_link}"
    when 'department'
      name = success_record['name'] || 'Unknown department'
      name
    when 'assignment_tenure'
      person_name = success_record['person_name'] || 'Unknown person'
      assignment_title = success_record['assignment_title'] || 'Unknown assignment'
      "#{person_name} - #{assignment_title}"
    when 'employment_tenure'
      person_name = success_record['person_name'] || 'Unknown person'
      position_title = success_record['position_title'] || 'Unknown position'
      "#{person_name} - #{position_title}"
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

  private

  def validate_source_contents_for_file_uploads
    if source_type == 'file_upload' && source_contents.blank?
      errors.add(:source_contents, 'is required for file uploads')
    end
  end

  def validate_filename_for_file_uploads
    if source_type == 'file_upload' && filename.blank?
      errors.add(:filename, 'is required for file uploads')
    end
  end
end
