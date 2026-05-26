# frozen_string_literal: true

module AbilitiesHrReview
  # Stable fingerprint for ability description + milestone text (used to split groups).
  class ContentFingerprint
    def self.call(description_normalized:, milestone_normalized:)
      parts = [description_normalized.to_s]
      (1..5).each { |n| parts << milestone_normalized["milestone_#{n}_normalized"].to_s }
      Digest::SHA256.hexdigest(parts.join("\x1e"))
    end
  end
end
