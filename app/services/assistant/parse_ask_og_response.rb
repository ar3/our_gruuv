# frozen_string_literal: true

module Assistant
  # Parses LLM JSON into answer + sanitized write-tool proposals.
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
      answer = @raw.to_s.strip.truncate(8_000) if answer.blank?

      actions = Array(json["proposed_actions"]).filter_map { |item| sanitize_action(item) }

      { answer: answer, proposed_actions: actions.first(2) }
    end

    private

    def extract_json(text)
      stripped = text.gsub(/\A```(?:json)?\s*/i, "").gsub(/\s*```\z/, "").strip
      parsed = JSON.parse(stripped)
      return parsed if parsed.is_a?(Hash)

      {}
    rescue JSON::ParserError
      match = text.match(/\{.*\}/m)
      return {} unless match

      JSON.parse(match[0])
    rescue JSON::ParserError
      {}
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
