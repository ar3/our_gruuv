# frozen_string_literal: true

module McpOauth
  module Pkce
    module_function

    def s256_challenge(code_verifier)
      digest = ::Digest::SHA256.digest(code_verifier.to_s)
      Base64.urlsafe_encode64(digest, padding: false)
    end

    def valid?(code_verifier:, code_challenge:, method: "S256")
      return false if code_verifier.blank? || code_challenge.blank?
      return false unless method.to_s == "S256"

      ActiveSupport::SecurityUtils.secure_compare(
        s256_challenge(code_verifier),
        code_challenge.to_s
      )
    rescue ArgumentError
      false
    end
  end
end
