class Giphy::Gateway
  class RetryableError < StandardError; end
  class NonRetryableError < StandardError; end

  def initialize(client: nil)
    @client = client || Giphy::Client.new(api_key: ENV['GIPHY_API_KEY'])
  end

  def search_gifs(query:, limit: 25)
    raise NonRetryableError, "GIPHY API key not configured" unless ENV['GIPHY_API_KEY'].present?

    response = @client.search(query: query, limit: limit)
    
    # Extract GIF data from GIPHY response
    gifs = response['data'] || []
    gifs.map do |gif|
      {
        id: gif['id'],
        title: gif['title'],
        url: gif['images']['original']['url'],
        preview_url: gif['images']['fixed_height']['url'],
        width: gif['images']['original']['width'],
        height: gif['images']['original']['height']
      }
    end
  rescue Giphy::Client::RateLimited => e
    raise RetryableError, "Rate limited: retry after #{e.retry_after_seconds} seconds"
  rescue Giphy::Client::Unauthorized => e
    raise NonRetryableError, e.message
  rescue Giphy::Client::BadRequest => e
    raise NonRetryableError, e.message
  rescue Giphy::Client::NetworkError => e
    raise RetryableError, e.message
  rescue Giphy::Client::Error => e
    raise NonRetryableError, e.message
  end
end

