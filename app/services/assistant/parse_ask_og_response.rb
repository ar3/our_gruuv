# frozen_string_literal: true

module Assistant
  # Parses LLM JSON into answer + sanitized write-tool proposals.
  # Never raises on malformed model JSON — falls back to raw answer text.
  class ParseAskOgResponse
    def self.call(raw)
      new(raw).call
    end

    def initialize(raw)
      @raw = raw.to_s
    end

    def call
      json = extract_json(@raw)
      answer = json["answer"].to_s.strip
      answer = fallback_answer if answer.blank?

      actions = Array(json["proposed_actions"]).filter_map { |item| sanitize_action(item) }

      { answer: answer, proposed_actions: actions.first(2) }
    end

    private

    def extract_json(text)
      candidates_for(text).each do |candidate|
        parsed = try_parse(candidate)
        return parsed if parsed.is_a?(Hash)
      end

      {}
    end

    def candidates_for(text)
      stripped = text.gsub(/\A```(?:json)?\s*/i, "").gsub(/\s*```\z/, "").strip
      candidates = [stripped, text.strip]
      if (match = text.match(/\{.*\}/m))
        candidates << match[0]
      end
      candidates.uniq
    end

    def try_parse(candidate)
      return nil if candidate.blank?

      parsed = JSON.parse(candidate)
      return parsed if parsed.is_a?(Hash)

      nil
    rescue JSON::ParserError
      nil
    end

    def fallback_answer
      # Prefer an answer-looking markdown body if the model wrapped JSON poorly.
      stripped = @raw.gsub(/\A```(?:json)?\s*/i, "").gsub(/\s*```\z/, "").strip
      if (match = stripped.match(/"answer"\s*:\s*"(?<body>(?:\\.|[^"\\])*)"/m))
        return unescape_json_string(match[:body]).truncate(8_000)
      end

      stripped.truncate(8_000)
    end

    def unescape_json_string(value)
      JSON.parse("\"#{value}\"")
    rescue JSON::ParserError
      value.to_s.gsub('\\n', "\n").gsub('\\"', '"').gsub('\\\\', '\\')
    end

    def sanitize_action(item)
      return nil unless item.is_a?(Hash)

      tool = item["tool"].to_s
      return nil unless AgentTools::Registry.write_tool?(tool)

      args = item["args"].is_a?(Hash) ? item["args"] : {}
      {
        "tool" => tool,
        "label" => item["label"].to_s.presence || tool.humanize,
        "summary" => item["summary"].to_s.presence || "Confirm to run #{tool}.",
        "args" => deep_stringify(args)
      }
    end

    def deep_stringify(value)
      case value
      when Hash
        value.each_with_object({}) { |(k, v), h| h[k.to_s] = deep_stringify(v) }
      when Array
        value.map { |v| deep_stringify(v) }
      else
        value
      end
    end
  end
end
