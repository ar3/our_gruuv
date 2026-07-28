# frozen_string_literal: true

module AgentTools
  # Single catalog of stable tool names → classes. MCP adapters map 1:1 to {.invoke}.
  module Registry
    # Class names as strings avoid Zeitwerk circular loads at boot.
    TOOLS = {
      "list_teammates" => "AgentTools::ListTeammates",
      "list_goals" => "AgentTools::ListGoals",
      "list_observations" => "AgentTools::ListObservations",
      "search_organization" => "AgentTools::SearchOrganization",
      "create_draft_observation" => "AgentTools::CreateDraftObservation",
      "set_current_week_goal_confidence" => "AgentTools::SetCurrentWeekGoalConfidence"
    }.freeze

    WRITE_TOOLS = %w[
      create_draft_observation
      set_current_week_goal_confidence
    ].freeze

    module_function

    def tool_names
      TOOLS.keys
    end

    def write_tool?(name)
      WRITE_TOOLS.include?(name.to_s)
    end

    def read_tool_names
      tool_names - WRITE_TOOLS
    end

    def fetch(name)
      class_name = TOOLS[name.to_s]
      raise ::AgentTools::UnknownTool, "Unknown AgentTool: #{name.inspect}" if class_name.blank?

      class_name.constantize
    end

    def invoke(name, context:, **args)
      fetch(name).call(context: context, **args)
    end

    # Compact schemas for LLM proposal prompts (not MCP wire format).
    def write_tool_schemas
      {
        "create_draft_observation" => {
          "args" => {
            "observee_path" => "string path from tool context (required), e.g. /organizations/.../company_teammates/.../internal",
            "story" => "string (optional draft story)",
            "observation_type" => "kudos|feedback|quick_note (default feedback)",
            "privacy_level" => "optional privacy enum (default observed_and_managers)",
            "goal_path" => "optional goal path from tool context"
          },
          "effect" => "Creates a draft OGO (published_at nil). Never publishes. Use paths, never numeric ids."
        },
        "set_current_week_goal_confidence" => {
          "args" => {
            "goal_path" => "string path from tool context (required) — active (not completed/deleted) goal only",
            "confidence_percentage" => "integer 0-100 (required)",
            "confidence_reason" => "string (optional for mid-range confidence)",
            "learnings" => "string required when confidence is 0 or 100 (completing the goal)"
          },
          "effect" => "Upserts confidence for the current Monday week only. Rejects completed/deleted goals. Completing (0%/100%) requires learnings."
        }
      }
    end
  end
end
