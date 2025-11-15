class Organizations::GifsController < Organizations::OrganizationNamespaceBaseController
  def search
    authorize Observation
    
    query = params[:q].to_s.strip
    limit = params[:limit]&.to_i || 25
    
    if query.blank?
      render json: { error: 'Query parameter is required' }, status: :bad_request
      return
    end
    
    gateway = Giphy::Gateway.new
    gifs = gateway.search_gifs(query: query, limit: limit)
    
    render json: { gifs: gifs }
  rescue Giphy::Gateway::RetryableError => e
    Rails.logger.error "GIPHY API retryable error: #{e.message}"
    render json: { error: 'Service temporarily unavailable. Please try again later.' }, status: :service_unavailable
  rescue Giphy::Gateway::NonRetryableError => e
    Rails.logger.error "GIPHY API error: #{e.message}"
    render json: { error: e.message }, status: :bad_request
  rescue => e
    Rails.logger.error "Unexpected error searching GIFs: #{e.message}"
    render json: { error: 'An unexpected error occurred' }, status: :internal_server_error
  end
end


