class Giphy::Client
  BASE_URL = 'https://api.giphy.com/v1'

  class Error < StandardError; end
  class RateLimited < Error
    attr_reader :retry_after_seconds
    
    def initialize(message, retry_after_seconds)
      super(message)
      @retry_after_seconds = retry_after_seconds
    end
  end
  class BadRequest < Error; end
  class Unauthorized < Error; end
  class NetworkError < Error; end

  def initialize(api_key:)
    @api_key = api_key
  end

  def search(query:, limit: 25)
    params = {
      api_key: @api_key,
      q: query,
      limit: limit
    }

    url = "#{BASE_URL}/gifs/search"
    response = HTTP.get(url, params: params)

    handle_response(response)
  rescue HTTP::Error, SocketError, Timeout::Error => e
    raise NetworkError, "Network error: #{e.message}"
  end

  private

  def handle_response(response)
    case response.status
    when 200
      JSON.parse(response.body.to_s)
    when 401
      raise Unauthorized, "Invalid API key"
    when 429
      retry_after = response.headers['Retry-After']&.to_i || 60
      raise RateLimited.new("Rate limited", retry_after)
    when 400..499
      raise BadRequest, "Bad request: #{response.status}"
    when 500..599
      raise NetworkError, "Server error: #{response.status}"
    else
      raise Error, "Unexpected status: #{response.status}"
    end
  end
end

