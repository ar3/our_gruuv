module Goals
  class ParseService
    attr_reader :textarea_content, :default_goal_type, :errors

    def initialize(textarea_content, default_goal_type)
      @textarea_content = textarea_content.to_s
      @default_goal_type = default_goal_type
      @errors = []
    end

    def call
      lines = parse_lines
      return { goals: [], errors: errors } if errors.any? && lines.empty?

      goals = build_goal_structures(lines)
      { goals: goals, errors: errors }
    end

    private

    def parse_lines
      textarea_content.split("\n")
                     .reject { |line| line.strip.blank? }
    end

    def leading_spaces(line)
      line.length - line.lstrip.length
    end

    def is_sub?(line)
      return false if line.blank?

      trimmed = line.strip
      return false if trimmed.empty?

      # Two or more leading spaces
      return true if leading_spaces(line) >= 2

      # Check if line starts with a number
      return true if trimmed.match?(/^\d/)

      # Check if line starts with *, •, -, or –
      return true if trimmed.start_with?('*', '•', '-', '–')

      # Check if line starts with 2 or more dots
      return true if trimmed.match?(/^\.{2,}/)

      # Single letter + period or closing paren (before roman so "I." / "i." are letter)
      return true if trimmed.match?(/^[A-Za-z]\./)
      return true if trimmed.match?(/^[A-Za-z]\)/)

      # Roman numeral + period or closing paren
      return true if trimmed.match?(/^[ivxlcdm]+\./i)
      return true if trimmed.match?(/^[ivxlcdm]+\)/i)

      false
    end

    def build_goal_structures(lines)
      goals = []
      return goals if lines.empty?

      i = 0
      most_recent_dom_index = nil

      while i < lines.length
        line = lines[i]
        is_sub = is_sub?(line)

        if is_sub
          # Edge case: sub at the start (no dom to attach to)
          if most_recent_dom_index.nil?
            goals << {
              title: line.strip,
              goal_type: default_goal_type,
              parent_index: nil,
              leading_spaces: -1
            }
            most_recent_dom_index = goals.length - 1
          else
            current_spaces = leading_spaces(line)
            # Parent is the most recent goal (dom or sub) with strictly fewer leading spaces
            parent_index = find_parent_index(goals, current_spaces)
            goals << {
              title: line.strip,
              goal_type: default_goal_type,
              parent_index: parent_index,
              leading_spaces: current_spaces
            }
          end
          i += 1
        else
          # It's a dom
          next_line = i + 1 < lines.length ? lines[i + 1] : nil
          next_is_sub = next_line && is_sub?(next_line)
          goals << {
            title: line.strip,
            goal_type: next_is_sub ? 'inspirational_objective' : default_goal_type,
            parent_index: nil,
            leading_spaces: -1
          }
          most_recent_dom_index = goals.length - 1
          i += 1
        end
      end

      # Remove internal leading_spaces from output (callers expect only title, goal_type, parent_index)
      goals.each { |g| g.delete(:leading_spaces) }
      goals
    end

    # Find index of the most recent goal whose leading_spaces is strictly less than current_spaces.
    # Doms have leading_spaces -1 so they are valid parents for any sub.
    def find_parent_index(goals, current_spaces)
      (goals.length - 1).downto(0) do |idx|
        return idx if goals[idx][:leading_spaces] < current_spaces
      end
      nil
    end
  end
end
