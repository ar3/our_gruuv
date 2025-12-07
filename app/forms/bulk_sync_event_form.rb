class BulkSyncEventForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :type, :string
  attribute :file
  attribute :organization_id, :integer
  attribute :creator_id, :integer
  attribute :initiator_id, :integer

  # Valid types include both upload and sync types
  VALID_TYPES = %w[
    BulkSyncEvent::UploadAssignmentCheckins
    BulkSyncEvent::UploadEmployees
    BulkSyncEvent::RefreshNamesSync
    BulkSyncEvent::RefreshSlackSync
  ].freeze

  validates :type, presence: true, inclusion: { in: VALID_TYPES }
  validates :organization_id, presence: true
  validates :creator_id, presence: true
  validates :initiator_id, presence: true
  
  # File validation only for upload types
  validate :validate_file_for_upload_types, if: :is_upload_type?

  def initialize(params = {})
    super
    @bulk_sync_event = nil
  end

  def save
    return false unless valid?
    
    begin
      @bulk_sync_event = type.constantize.new(bulk_sync_event_attributes)
      @bulk_sync_event.organization_id = organization_id
      @bulk_sync_event.creator_id = creator_id
      @bulk_sync_event.initiator_id = initiator_id
      
      if is_upload_type?
        # Handle file uploads
        if file.present?
          @bulk_sync_event.filename = file.original_filename
          @bulk_sync_event.source_contents = process_file_content_for_storage
          @bulk_sync_event.source_data = {
            type: 'file_upload',
            filename: file.original_filename,
            file_size: file.size,
            uploaded_at: Time.current.iso8601
          }
        else
          errors.add(:file, 'is required for file uploads')
          return false
        end
      else
        # Handle sync types (no file needed)
        @bulk_sync_event.source_data = {
          type: sync_source_type,
          fetched_at: Time.current.iso8601
        }
      end
      
      if @bulk_sync_event.save
        process_for_preview
      else
        @bulk_sync_event.errors.each { |error| errors.add(error.attribute, error.message) }
        false
      end
    rescue NameError => e
      errors.add(:type, 'Invalid sync type')
      false
    rescue => e
      errors.add(:base, "An error occurred: #{e.message}")
      false
    end
  end

  def bulk_sync_event
    @bulk_sync_event
  end

  def success?
    @bulk_sync_event&.persisted? && @bulk_sync_event&.preview_actions.is_a?(Hash)
  end

  def preview_ready?
    @bulk_sync_event&.preview_actions.present?
  end

  def parse_error_message
    return nil unless @bulk_sync_event
    
    parser = determine_parser
    return nil unless parser
    
    parser.errors.join(', ')
  end

  private

  def bulk_sync_event_attributes
    { type: type }
  end

  def is_upload_type?
    type.in?(['BulkSyncEvent::UploadAssignmentCheckins', 'BulkSyncEvent::UploadEmployees'])
  end

  def is_sync_type?
    type.in?(['BulkSyncEvent::RefreshNamesSync', 'BulkSyncEvent::RefreshSlackSync'])
  end

  def sync_source_type
    case type
    when 'BulkSyncEvent::RefreshNamesSync'
      'database_sync'
    when 'BulkSyncEvent::RefreshSlackSync'
      'slack_sync'
    else
      'unknown'
    end
  end

  def validate_file_for_upload_types
    return unless is_upload_type?
    
    if file.blank?
      errors.add(:file, 'is required for file uploads')
      return
    end
    
    begin
      sync_class = type.constantize
      unless sync_class.new.validate_file_type(file)
        errors.add(:file, "Please upload a valid #{sync_class.new.file_extension.upcase} file")
      end
    rescue NameError
      errors.add(:type, 'Invalid sync type')
    end
  end

  def process_file_content_for_storage
    return nil unless file.present? && type.present?
    
    begin
      sync_class = type.constantize
      sync_instance = sync_class.new
      sync_instance.process_file_content_for_storage(file)
    rescue => e
      errors.add(:file, "Error processing file: #{e.message}")
      nil
    end
  end

  def process_for_preview
    return false unless @bulk_sync_event&.persisted?
    
    begin
      if @bulk_sync_event.process_file_for_preview
        # Check if preview_actions were actually set (even if empty)
        if @bulk_sync_event.preview_actions.is_a?(Hash)
          true
        else
          @bulk_sync_event.destroy
          errors.add(:base, 'No preview actions generated')
          false
        end
      else
        @bulk_sync_event.destroy
        # Add parsing errors to form errors
        parser = determine_parser
        if parser&.errors&.any?
          errors.add(:base, parser.errors.join(', '))
        else
          errors.add(:base, 'Failed to process preview')
        end
        false
      end
    rescue => e
      @bulk_sync_event.destroy if @bulk_sync_event.persisted?
      errors.add(:base, "Error processing preview: #{e.message}")
      false
    end
  end

  def determine_parser
    return nil unless @bulk_sync_event
    
    begin
      case @bulk_sync_event
      when BulkSyncEvent::UploadAssignmentCheckins
        EmploymentDataUploadParser.new(@bulk_sync_event.source_contents) if @bulk_sync_event.source_contents.present?
      when BulkSyncEvent::UploadEmployees
        UnassignedEmployeeUploadParser.new(@bulk_sync_event.source_contents) if @bulk_sync_event.source_contents.present?
      when BulkSyncEvent::RefreshNamesSync
        RefreshNamesSyncParser.new(@bulk_sync_event.organization)
      when BulkSyncEvent::RefreshSlackSync
        RefreshSlackSyncParser.new(@bulk_sync_event.organization)
      else
        nil
      end
    rescue => e
      errors.add(:base, "Error creating parser: #{e.message}")
      nil
    end
  end
end
