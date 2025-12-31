module S3
  class ImageUploader
    BUCKET_NAME = 'static.ourgruuv.com'
    
    def initialize
      @access_key_id = ENV['AWS_ACCESS_KEY_ID'] || Rails.application.credentials.dig(:aws, :access_key_id)
      @secret_access_key = ENV['AWS_SECRET_ACCESS_KEY'] || Rails.application.credentials.dig(:aws, :secret_access_key)
      @region = ENV['AWS_REGION'] || 'us-east-1'
    end

    def upload(file, folder: 'change-logs')
      raise ArgumentError, 'File is required' unless file.present?
      
      # Generate unique filename with timestamp
      original_filename = file.respond_to?(:original_filename) ? file.original_filename : 'image'
      extension = File.extname(original_filename).presence || '.jpg'
      base_name = File.basename(original_filename, extension)
      # Sanitize filename: remove special characters, keep only alphanumeric, dash, underscore
      sanitized_base = base_name.present? ? base_name.gsub(/[^a-zA-Z0-9_-]/, '_') : 'image'
      timestamp = Time.current.to_i
      unique_filename = "#{sanitized_base}_#{timestamp}#{extension}"
      s3_key = "#{folder}/#{unique_filename}"
      
      s3_resource = Aws::S3::Resource.new(
        access_key_id: @access_key_id,
        secret_access_key: @secret_access_key,
        region: @region
      )

      bucket = s3_resource.bucket(BUCKET_NAME)
      object = bucket.object(s3_key)
      
      # Read file content (rewind to ensure we read from the beginning)
      file.rewind if file.respond_to?(:rewind)
      file_content = file.read
      
      # Upload with public read permissions
      object.put(
        body: file_content,
        acl: 'public-read',
        content_type: file.content_type || 'image/jpeg'
      )
      
      # Return the public S3 URL
      "https://s3.#{@region}.amazonaws.com/#{BUCKET_NAME}/#{s3_key}"
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error "S3::ImageUploader: Failed to upload image - #{e.message}"
      raise
    end
  end
end

