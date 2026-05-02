# frozen_string_literal: true

module Maap
  # Parses trailing CLARITY_SIGNAL line from model output; strips it from displayed body.
  class ClaritySignalParser
    SIGNAL_PATTERN = /\n\s*CLARITY_SIGNAL:\s*(GREEN|YELLOW|RED)\s*\z/i

    Result = Struct.new(:rating, :body, keyword_init: true)

    # @return [Result] rating is one of CLARITY_RATINGS or nil if missing/unparseable
    def self.call(raw_text)
      text = raw_text.to_s.strip
      return Result.new(rating: nil, body: text) if text.blank?

      m = text.match(SIGNAL_PATTERN)
      unless m
        return Result.new(rating: fallback_rating_from_verdict(text), body: text)
      end

      rating = m[1].downcase
      body = text.sub(SIGNAL_PATTERN, '').strip
      Result.new(rating: rating, body: body)
    end

    def self.fallback_rating_from_verdict(text)
      t = text.downcase
      return 'green' if t.include?('verdict') && t.match?(/\bclear\b/) && !t.match?(/mostly clear|insufficient/)
      return 'yellow' if t.match?(/mostly clear|needs revision|insufficient data/)
      return 'red' if t.match?(/\bunclear\b/)

      nil
    end
    private_class_method :fallback_rating_from_verdict
  end
end
