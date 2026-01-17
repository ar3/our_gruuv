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
                     .map(&:strip)
                     .reject(&:blank?)
    end

    def is_sub?(line)
      return false if line.blank?

      trimmed = line.strip
      return false if trimmed.empty?

      # Check if line starts with a number
      return true if trimmed.match?(/^\d/)

      # Check if line starts with *, •, -, or –
      return true if trimmed.start_with?('*', '•', '-', '–')

      # Check if line starts with 2 or more dots
      return true if trimmed.match?(/^\.{2,}/)

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
          # Treat it as a dom with default goal type
          if most_recent_dom_index.nil?
            goals << {
              title: line,
              goal_type: default_goal_type,
              parent_index: nil
            }
            most_recent_dom_index = goals.length - 1
          else
            # Attach to the most recent dom
            goals << {
              title: line,
              goal_type: default_goal_type,
              parent_index: most_recent_dom_index
            }
          end
          i += 1
        else
          # It's a dom
          # Check if next line is a sub
          next_line = i + 1 < lines.length ? lines[i + 1] : nil
          next_is_sub = next_line && is_sub?(next_line)

          if next_is_sub
            # Dom followed by subs - dom becomes objective
            goals << {
              title: line,
              goal_type: 'inspirational_objective',
              parent_index: nil
            }
            dom_index = goals.length - 1
            most_recent_dom_index = dom_index

            # Process all following subs until we hit another dom
            i += 1
            while i < lines.length && is_sub?(lines[i])
              goals << {
                title: lines[i],
                goal_type: default_goal_type,
                parent_index: dom_index
              }
              i += 1
            end
          else
            # Dom followed by another dom (or end of input)
            # First dom gets default goal type
            goals << {
              title: line,
              goal_type: default_goal_type,
              parent_index: nil
            }
            most_recent_dom_index = goals.length - 1
            i += 1
          end
        end
      end

      goals
    end
  end
end
