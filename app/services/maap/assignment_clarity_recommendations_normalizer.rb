# frozen_string_literal: true

module Maap
  # Normalizes model-emitted recommendation objects for assignment Consult OG (Phase 1–3).
  class AssignmentClarityRecommendationsNormalizer
    MAX_ITEMS = 10
    ALLOWED_CONFIDENCE = %w[high].freeze

    def self.call(raw)
      return [] if raw.nil?

      arr =
        case raw
        when String
          parse_json_array(raw)
        when Array
          raw
        else
          return []
        end

      return [] unless arr.is_a?(Array)

      arr.first(MAX_ITEMS).filter_map { |item| normalize_one(item) }
    end

    def self.parse_json_array(str)
      s = str.to_s.strip
      return [] if s.blank?

      parsed = JSON.parse(s)
      parsed.is_a?(Array) ? parsed : []
    rescue JSON::ParserError
      []
    end

    def self.normalize_one(item)
      return nil unless item.is_a?(Hash)

      h = item.stringify_keys
      id = h['id'].to_s.strip
      confidence = h['confidence'].to_s.downcase
      title = h['title'].to_s.strip
      rationale = h['rationale'].to_s.strip
      kind = h['kind'].to_s.strip
      return nil if id.blank?
      return nil unless ALLOWED_CONFIDENCE.include?(confidence)
      return nil if title.blank? || rationale.blank? || kind.blank?

      payload = h['payload']
      payload = payload.is_a?(Hash) ? payload.stringify_keys : {}

      {
        'id' => id,
        'confidence' => confidence,
        'kind' => kind,
        'title' => title.truncate(500),
        'rationale' => rationale.truncate(5000),
        'payload' => payload
      }
    end
  end
end
