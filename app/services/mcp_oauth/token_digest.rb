# frozen_string_literal: true

module McpOauth
  module TokenDigest
    module_function

    def digest(raw)
      ::Digest::SHA256.hexdigest(raw.to_s)
    end

    def generate_token(prefix)
      "#{prefix}#{SecureRandom.urlsafe_base64(32)}"
    end
  end
end
