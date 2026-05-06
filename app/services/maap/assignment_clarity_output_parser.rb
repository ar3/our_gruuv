# frozen_string_literal: true

module Maap
  # Parses trailing CLARITY_SCORE_TOTAL + CLARITY_SIGNAL from assignment Consult OG output, or falls back to {ClaritySignalParser}.
  class AssignmentClarityOutputParser
    RECOMMENDATIONS_BLOCK =
      /BEGIN_MAAP_RECOMMENDATIONS\s*\r?\n(?<json>[\s\S]*?)\r?\nEND_MAAP_RECOMMENDATIONS\s*\r?\n?/m.freeze
    SCORE_AND_SIGNAL_TRAILING =
      /\n\s*CLARITY_SCORE_TOTAL:\s*(\d{1,3})\s*\n\s*CLARITY_SIGNAL:\s*(GREEN|YELLOW|RED)\s*\z/i.freeze
    SCORE_ONLY_TRAILING = /\n\s*CLARITY_SCORE_TOTAL:\s*(\d{1,3})\s*\z/i.freeze

    Result = Struct.new(:score, :rating, :body, :recommendations, keyword_init: true)

    # @return [Result] rating follows bands when score present (80/60); else legacy signal-only parsing.
    def self.call(raw_text)
      text = raw_text.to_s.strip
      return empty_result if text.blank?

      text, recommendations_json = strip_recommendations_block(text)
      recommendations = AssignmentClarityRecommendationsNormalizer.call(recommendations_json)

      result = parse_score_and_rating(text)
      result.recommendations = recommendations
      result
    end

    def self.empty_result
      Result.new(score: nil, rating: nil, body: '', recommendations: [])
    end

    def self.strip_recommendations_block(text)
      m = text.match(RECOMMENDATIONS_BLOCK)
      return [text, nil] unless m

      json_chunk = m[:json].to_s.strip
      stripped = text.sub(RECOMMENDATIONS_BLOCK, '').strip
      [stripped, json_chunk.presence]
    end

    def self.parse_score_and_rating(text)
      if (m = text.match(SCORE_AND_SIGNAL_TRAILING))
        score = normalize_score(m[1])
        body = text.sub(SCORE_AND_SIGNAL_TRAILING, '').strip
        return Result.new(score: score, rating: rating_from_score(score), body: body, recommendations: [])
      end

      if (m = text.match(SCORE_ONLY_TRAILING))
        score = normalize_score(m[1])
        body = text.sub(SCORE_ONLY_TRAILING, '').strip
        return Result.new(score: score, rating: rating_from_score(score), body: body, recommendations: [])
      end

      legacy = ClaritySignalParser.call(text)
      Result.new(score: nil, rating: legacy.rating, body: legacy.body, recommendations: [])
    end

    private_class_method :strip_recommendations_block, :parse_score_and_rating

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
