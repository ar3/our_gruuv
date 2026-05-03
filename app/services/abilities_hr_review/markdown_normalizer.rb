# frozen_string_literal: true

module AbilitiesHrReview
  # Deterministic Markdown fixes: list markers need a space after *; horizontal rules need blank lines.
  class MarkdownNormalizer
    def self.call(text)
      new(text).call
    end

    def initialize(text)
      @text = text.to_s.dup
    end

    def call
      return '' if @text.blank?

      # Ensure "*word" -> "* word" at line start (unordered lists)
      out = @text.gsub(/^( *)(\*+)([^\s*])/m) { "#{Regexp.last_match(1)}#{Regexp.last_match(2)} #{Regexp.last_match(3)}" }

      # Standalone HR lines: ---, ***, ___ on their own line → wrap with newlines so Markdown renders <hr>
      out.gsub!(/^(\s*)(-{3,}|\*{3,}|_{3,})\s*$/m) do
        m = Regexp.last_match
        "\n\n#{m[1]}#{m[2]}\n\n"
      end

      # Collapse excessive blank lines from HR wrapping (max 2 consecutive)
      out.gsub(/\n{4,}/, "\n\n\n")

      out.strip
    end
  end
end
