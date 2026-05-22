# frozen_string_literal: true

# Escapes text for Mermaid flowchart DSL (v11+). Unescaped [, ], #, ;, &, etc. in node
# labels or click URLs cause "Syntax error in text".
module MermaidFlowchartEscaping
  LABEL_CHARACTER_ESCAPES = {
    '\\' => '#92;',
    '"' => '#quot;',
    '#' => '#35;',
    '[' => '#91;',
    ']' => '#93;',
    '(' => '#40;',
    ')' => '#41;',
    '{' => '#123;',
    '}' => '#125;',
    '<' => '#60;',
    '>' => '#62;',
    '&' => '#38;',
    ';' => '#59;',
    '|' => '#124;',
    '%' => '#37;',
    ':' => '#58;',
    "'" => '#39;'
  }.freeze

  private

  def mermaid_normalize_flowchart_text(text)
    text.to_s.gsub(/[\r\n]+/, ' ').strip
  end

  def mermaid_escape_flowchart_label(text)
    normalized = mermaid_normalize_flowchart_text(text)
    # Sequences that Mermaid parses as arrow syntax even inside node labels.
    normalized = normalized.gsub(/->/, ' to ').gsub(/--+/, ' - ')
    normalized.chars.map { |char| LABEL_CHARACTER_ESCAPES.fetch(char, char) }.join
  end
end
