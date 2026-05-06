# frozen_string_literal: true

module Maap
  # Parses trailing CLARITY_SCORE_TOTAL + CLARITY_SIGNAL from assignment Consult OG output, or falls back to {ClaritySignalParser}.
  class AssignmentClarityOutputParser
    SCORE_AND_SIGNAL_TRAILING =
      /\n\s*CLARITY_SCORE_TOTAL:\s*(\d{1,3})\s*\n\s*CLARITY_SIGNAL:\s*(GREEN|YELLOW|RED)\s*\z/i.freeze
    SCORE_ONLY_TRAILING = /\n\s*CLARITY_SCORE_TOTAL:\s*(\d{1,3})\s*\z/i.freeze

    Result = Struct.new(:score, :rating, :body, keyword_init: true)

    # @return [Result] rating follows bands when score present (80/60); else legacy signal-only parsing.
    def self.call(raw_text)
      text = raw_text.to_s.strip
      return Result.new(score: nil, rating: nil, body: text) if text.blank?

      if (m = text.match(SCORE_AND_SIGNAL_TRAILING))
        score = normalize_score(m[1])
        body = text.sub(SCORE_AND_SIGNAL_TRAILING, '').strip
        return Result.new(score: score, rating: rating_from_score(score), body: body)
      end

      if (m = text.match(SCORE_ONLY_TRAILING))
        score = normalize_score(m[1])
        body = text.sub(SCORE_ONLY_TRAILING, '').strip
        return Result.new(score: score, rating: rating_from_score(score), body: body)
      end

      legacy = ClaritySignalParser.call(text)
      Result.new(score: nil, rating: legacy.rating, body: legacy.body)
    end

    def self.rating_from_score(score)
      return nil if score.nil?

      return 'green' if score >= 80
      return 'yellow' if score >= 60

      'red'
    end

    def self.normalize_score(str)
      n = str.to_i
      [[n, 0].max, 100].min
    end
  end
end
