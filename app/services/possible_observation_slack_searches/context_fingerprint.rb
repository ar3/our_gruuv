# frozen_string_literal: true

require "digest"

module PossibleObservationSlackSearches
  # SHA256 of SubjectContextPack.prompt_text for memo uniqueness.
  class ContextFingerprint
    def self.compute(prompt_text)
      Digest::SHA256.hexdigest(prompt_text.to_s)
    end
  end
end
