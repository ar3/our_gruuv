class UploadEventForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :type, :string
  attribute :file
  attribute :organization_id, :integer
  attribute :creator_id, :integer
  attribute :initiator_id, :integer

  validates :type, presence: true, inclusion: { in: %w[UploadEvent::UploadAssignmentCheckins UploadEvent::UploadEmployees] }
  validates :file, presence: true
  validates :organization_id, presence: true
  validates :creator_id, presence: true
  validates :initiator_id, presence: true

  validate :validate_file_type, if: :file_present?

  def initialize(params = {})
    super
    @upload_event = nil
  end

  def save
    return false unless valid?
    
    begin
      @upload_event = type.constantize.new(upload_event_attributes)
      @upload_event.organization_id = organization_id
      @upload_event.creator_id = creator_id
      @upload_event.initiator_id = initiator_id
      
      if file.present?
        @upload_event.filename = file.original_filename
        @upload_event.file_content = process_file_content_for_storage
      end
      
      if @upload_event.save
        process_file_for_preview
      else
        @upload_event.errors.each { |error| errors.add(error.attribute, error.message) }
        false
      end
    rescue NameError => e
      errors.add(:type, 'Invalid upload type')
      false
    rescue => e
      errors.add(:base, "An error occurred: #{e.message}")
      false
    end
  end

  def upload_event
    @upload_event
  end

  def success?
    @upload_event&.persisted? && @upload_event&.preview_actions.is_a?(Hash)
  end

  def preview_ready?
    @upload_event&.preview_actions.present?
  end

  def parse_error_message
    return nil unless @upload_event
    
    parser = determine_parser
    return nil unless parser
    
    parser.errors.join(', ')
  end

  private

  def upload_event_attributes
    { type: type }
  end

  def file_present?
    file.present?
  end

  def validate_file_type
    return unless file.present? && type.present?
    
    begin
      upload_class = type.constantize
      unless upload_class.new.validate_file_type(file)
        errors.add(:file, "Please upload a valid #{upload_class.new.file_extension.upcase} file")
      end
    rescue NameError
      errors.add(:type, 'Invalid upload type')
    end
  end

  def process_file_content_for_storage
    return nil unless file.present? && type.present?
    
    begin
      upload_class = type.constantize
      upload_instance = upload_class.new
      upload_instance.process_file_content_for_storage(file)
    rescue => e
      errors.add(:file, "Error processing file: #{e.message}")
      nil
    end
  end

  def process_file_for_preview
    return false unless @upload_event&.persisted?
    
    begin
      if @upload_event.process_file_for_preview
        # Check if preview_actions were actually set (even if empty)
        if @upload_event.preview_actions.is_a?(Hash)
          true
        else
          @upload_event.destroy
          errors.add(:base, 'No preview actions generated')
          false
        end
      else
        @upload_event.destroy
        # Add parsing errors to form errors
        parser = determine_parser
        if parser&.errors&.any?
          errors.add(:base, parser.errors.join(', '))
        else
          errors.add(:base, 'Failed to process file preview')
        end
        false
      end
    rescue => e
      @upload_event.destroy if @upload_event.persisted?
      errors.add(:base, "Error processing preview: #{e.message}")
      false
    end
  end

  def determine_parser
    return nil unless @upload_event&.file_content.present?
    
    begin
      case @upload_event
      when UploadEvent::UploadAssignmentCheckins
        EmploymentDataUploadParser.new(@upload_event.file_content)
      when UploadEvent::UploadEmployees
        UnassignedEmployeeUploadParser.new(@upload_event.file_content)
      else
        nil
      end
    rescue => e
      errors.add(:base, "Error creating parser: #{e.message}")
      nil
    end
  end
end
