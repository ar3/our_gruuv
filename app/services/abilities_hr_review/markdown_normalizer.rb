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

      # Ensure "*word" -> "* word" at line start (unordered lists). Skip lines that are entirely *wrapped*
      # (italic/bold), so we do not insert a space after the opening *.
      lines = @text.split(/\r?\n/, -1)
      out = lines.map do |line|
        next line if italic_wrapped_line?(line)

        line.gsub(/^( *)(\*+)([^\s*])/) { "#{Regexp.last_match(1)}#{Regexp.last_match(2)} #{Regexp.last_match(3)}" }
      end.join("\n")

      # Standalone HR lines: ---, ***, ___ on their own line → wrap with newlines so Markdown renders <hr>
      out.gsub!(/^(\s*)(-{3,}|\*{3,}|_{3,})\s*$/m) do
        m = Regexp.last_match
        "\n\n#{m[1]}#{m[2]}\n\n"
      end

      # Collapse excessive blank lines from HR wrapping (max 2 consecutive)
      out.gsub(/\n{4,}/, "\n\n\n")

      out.strip
    end

    private

    # Whole-line emphasis: stripped line begins and ends with * and has non-empty content between.
    def italic_wrapped_line?(line)
      s = line.strip
      return false if s.length < 3
      return false unless s.start_with?('*') && s.end_with?('*')

      inner = s[1..-2]
      inner.present?
    end
  end
end
