class PendoService
  def initialize(api_key)
    @api_key = api_key
  end

  def test_connection
    # Simple API call to test connection
    response = HTTP.headers("X-Pendo-Integration-Key" => @api_key)
                   .get("https://app.pendo.io/api/v1/guide")
    
    response.status == 200
  end

  def fetch_guides(limit: nil, active_only: true)
    # Build query parameters
    params = {}
    params[:limit] = limit if limit.present?
    params[:active] = active_only if active_only
    # params[:summarizeContent] = :true

    # Build URL with query parameters
    url = "https://app.pendo.io/api/v1/guide"
    if params.any?
      query_string = params.map { |k, v| "#{k}=#{v}" }.join("&")
      url += "?#{query_string}"
    end
    
    response = HTTP.headers("X-Pendo-Integration-Key" => @api_key)
                   .get(url)
    
    raise "Failed to fetch guides: #{response.status}" unless response.status == 200
    
    # Debug: print the raw response
    puts "Pendo API Response: #{response.body.to_s}"
    
    parsed_response = JSON.parse(response.body.to_s)
    
    # Handle different possible response structures
    if parsed_response.is_a?(Array)
      parsed_response
    elsif parsed_response.is_a?(Hash)
      parsed_response["data"] || parsed_response["guides"] || []
    else
      []
    end
  end

  def get_guide_details(guide_id)
    response = HTTP.headers("X-Pendo-Integration-Key" => @api_key)
                   .get("https://app.pendo.io/api/v1/guide/#{guide_id}")
    
    raise "Failed to fetch guide details: #{response.status}" unless response.status == 200
    
    JSON.parse(response.body.to_s)["data"]
  end
end
