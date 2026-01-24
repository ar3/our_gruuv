module S3
  class CsvUploader
    def bucket_name
      ENV['BULK_DOWNLOADS_S3_BUCKET'] || 'bulk-downloads.ourgruuv.com'
    end
    
    def initialize
      @access_key_id = ENV['AWS_ACCESS_KEY_ID'] || Rails.application.credentials.dig(:aws, :access_key_id)
      @secret_access_key = ENV['AWS_SECRET_ACCESS_KEY'] || Rails.application.credentials.dig(:aws, :secret_access_key)
      @region = ENV['AWS_REGION'] || 'us-east-1'
    end

    def upload(csv_content, filename:, organization_id:, download_type:)
      raise ArgumentError, 'CSV content is required' unless csv_content.present?
      raise ArgumentError, 'Filename is required' unless filename.present?
      raise ArgumentError, 'Organization ID is required' unless organization_id.present?
      raise ArgumentError, 'Download type is required' unless download_type.present?
      
      # Generate unique filename with timestamp
      extension = File.extname(filename).presence || '.csv'
      base_name = File.basename(filename, extension)
      # Sanitize filename: remove special characters, keep only alphanumeric, dash, underscore
      sanitized_base = base_name.present? ? base_name.gsub(/[^a-zA-Z0-9_-]/, '_') : 'download'
      timestamp = Time.current.to_i
      unique_filename = "#{sanitized_base}_#{timestamp}#{extension}"
      s3_key = "bulk-downloads/#{organization_id}/#{download_type}/#{unique_filename}"
      
      s3_resource = Aws::S3::Resource.new(
        access_key_id: @access_key_id,
        secret_access_key: @secret_access_key,
        region: @region
      )

      bucket = s3_resource.bucket(bucket_name)
      object = bucket.object(s3_key)
      
      # Upload with private ACL for security
      object.put(
        body: csv_content,
        acl: 'private',
        content_type: 'text/csv'
      )
      
      # Return hash with s3_key and s3_url
      {
        s3_key: s3_key,
        s3_url: "https://#{bucket_name}.s3.#{@region}.amazonaws.com/#{s3_key}"
      }
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error "S3::CsvUploader: Failed to upload CSV - #{e.message}"
      raise
    end

    def download(s3_key)
      raise ArgumentError, 'S3 key is required' unless s3_key.present?
      
      s3_resource = Aws::S3::Resource.new(
        access_key_id: @access_key_id,
        secret_access_key: @secret_access_key,
        region: @region
      )

      bucket = s3_resource.bucket(bucket_name)
      object = bucket.object(s3_key)
      
      object.get.body.read
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error "S3::CsvUploader: Failed to download CSV - #{e.message}"
      raise
    end
  end
end
