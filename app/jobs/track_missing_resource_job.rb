class TrackMissingResourceJob < ApplicationJob
  queue_as :default

  def perform(path, person_id, ip_address, user_agent, referrer, request_method, query_string)
    Rails.logger.info "TrackMissingResourceJob: Tracking missing resource - path: #{path}, person_id: #{person_id}, ip: #{ip_address}"

    # Find or create MissingResource
    missing_resource = MissingResource.find_or_initialize_by(path: path)
    
    if missing_resource.new_record?
      # New resource: set initial values
      missing_resource.request_count = 0
      missing_resource.first_seen_at = Time.current
      missing_resource.last_seen_at = Time.current
      missing_resource.save!
    end
    
    # Increment count and update last_seen_at atomically
    missing_resource.increment_request_count!
    missing_resource.update!(first_seen_at: Time.current) if missing_resource.first_seen_at.nil?

    # Find or initialize MissingResourceRequest with unique constraint
    # The unique constraint is on (missing_resource_id, person_id, ip_address)
    request_attrs = {
      missing_resource: missing_resource,
      person_id: person_id,
      ip_address: ip_address
    }

    missing_resource_request = MissingResourceRequest.find_or_initialize_by(request_attrs)

    if missing_resource_request.new_record?
      # New record: set initial values
      missing_resource_request.request_count = 1
      missing_resource_request.first_seen_at = Time.current
      missing_resource_request.last_seen_at = Time.current
      missing_resource_request.user_agent = user_agent
      missing_resource_request.referrer = referrer
      missing_resource_request.request_method = request_method
      missing_resource_request.query_string = query_string
      missing_resource_request.save!
    else
      # Existing record: increment count and update metadata
      missing_resource_request.increment_request_count!
      missing_resource_request.update_metadata!(
        user_agent: user_agent,
        referrer: referrer,
        request_method: request_method,
        query_string: query_string
      )
    end

    Rails.logger.info "TrackMissingResourceJob: Successfully tracked - MissingResource ID: #{missing_resource.id}, Request ID: #{missing_resource_request.id}"
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "TrackMissingResourceJob: Validation error - #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    # Don't re-raise - we don't want tracking failures to break the request
  rescue => e
    Rails.logger.error "TrackMissingResourceJob: Unexpected error: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    # Don't re-raise - we don't want tracking failures to break the request
  end
end

