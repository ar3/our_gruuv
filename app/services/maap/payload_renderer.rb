# frozen_string_literal: true

module Maap
  # Renders agent payload hashes as Markdown for the LLM user message.
  class PayloadRenderer
    def initialize(payload)
      @payload = payload.respond_to?(:deep_stringify_keys) ? payload.deep_stringify_keys : {}
    end

    def to_markdown
      sections = @payload['sections']
      return render_value(@payload) if sections.blank?

      lines = []
      sections.each do |section|
        title = section['title'].presence || 'Section'
        lines << "## #{title}"
        lines << ''
        lines << render_value(section['body'])
        lines << ''
      end
      lines.join("\n").strip
    end

    private

    def render_value(obj, depth = 0)
      case obj
      when Hash
        obj.map do |k, v|
          bullet = "#{'  ' * depth}- **#{k}:** #{render_inline(v)}"
          nested = v.is_a?(Hash) || v.is_a?(Array) ? "\n#{render_value(v, depth + 1)}" : ''
          bullet + nested
        end.join("\n")
      when Array
        obj.map.with_index do |item, idx|
          if item.is_a?(Hash)
            "- Item #{idx + 1}\n#{render_value(item, depth + 1)}"
          else
            "- #{render_inline(item)}"
          end
        end.join("\n")
      else
        obj.to_s.presence || '—'
      end
    end

    def render_inline(obj)
      case obj
      when Hash, Array
        "\n#{render_value(obj)}"
      else
        obj.to_s.presence || '—'
      end
    end
  end
end
