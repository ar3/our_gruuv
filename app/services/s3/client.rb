module S3
  class Client
    def initialize
      @bucket_name = ENV['SLACK_EVENTS_S3_BUCKET']
      @access_key_id = ENV['AWS_ACCESS_KEY_ID'] || Rails.application.credentials.dig(:aws, :access_key_id)
      @secret_access_key = ENV['AWS_SECRET_ACCESS_KEY'] || Rails.application.credentials.dig(:aws, :secret_access_key)
      @region = ENV['AWS_REGION'] || 'us-east-1'
    end

    def save_json_to_s3(full_file_path_and_name:, hash_object:)
      raise ArgumentError, 'S3 bucket name is required' unless @bucket_name.present?

      s3_resource = Aws::S3::Resource.new(
        access_key_id: @access_key_id,
        secret_access_key: @secret_access_key,
        region: @region
      )

      bucket = s3_resource.bucket(@bucket_name)
      object = bucket.object(full_file_path_and_name)
      object.put(body: hash_object.to_json)

      true
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error "S3::Client: Failed to save to S3 - #{e.message}"
      raise
    end
  end
end

