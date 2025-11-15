class Giphy::FakeGateway
  class RetryableError < StandardError; end
  class NonRetryableError < StandardError; end

  def initialize
    @gifs = []
  end

  def search_gifs(query:, limit: 25)
    # Return fake GIF data for testing
    (1..limit).map do |i|
      {
        id: "fake_gif_#{i}",
        title: "Fake GIF #{i} for '#{query}'",
        url: "https://media.giphy.com/media/fake#{i}/giphy.gif",
        preview_url: "https://media.giphy.com/media/fake#{i}/200w.gif",
        width: 480,
        height: 270
      }
    end
  end
end


