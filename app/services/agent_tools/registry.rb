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

    # JSON Schema–style input schemas for MCP and other machine clients.
    INPUT_SCHEMAS = {
      "list_teammates" => {
        type: "object",
        properties: {
          query: { type: "string", description: "Optional name/email filter" },
          limit: { type: "integer", description: "Max results (1–50)", minimum: 1, maximum: 50 }
        },
        additionalProperties: false
      },
      "list_goals" => {
        type: "object",
        properties: {
          needing_check_in: { type: "boolean", description: "If true, only goals needing a confidence check-in" },
          limit: { type: "integer", description: "Max results (1–50)", minimum: 1, maximum: 50 }
        },
        additionalProperties: false
      },
      "list_observations" => {
        type: "object",
        properties: {
          query: { type: "string", description: "Optional story text filter" },
          limit: { type: "integer", description: "Max results (1–50)", minimum: 1, maximum: 50 }
        },
        additionalProperties: false
      },
      "search_organization" => {
        type: "object",
        properties: {
          query: { type: "string", description: "Search query (required)" }
        },
        required: ["query"],
        additionalProperties: false
      },
      "create_draft_observation" => {
        type: "object",
        properties: {
          observee_path: {
            type: "string",
            description: "Path from list/search tools, e.g. /organizations/.../company_teammates/.../internal"
          },
          story: { type: "string", description: "Optional draft story" },
          observation_type: {
            type: "string",
            enum: %w[kudos feedback quick_note],
            description: "Defaults to feedback"
          },
          privacy_level: {
            type: "string",
            description: "Privacy enum; default observed_and_managers"
          },
          goal_path: { type: "string", description: "Optional goal path from tool results" }
        },
        required: ["observee_path"],
        additionalProperties: false
      },
      "set_current_week_goal_confidence" => {
        type: "object",
        properties: {
          goal_path: { type: "string", description: "Goal path from tool results (active goals only)" },
          confidence_percentage: {
            type: "integer",
            minimum: 0,
            maximum: 100,
            description: "Confidence 0–100 for the current Monday week"
          },
          confidence_reason: { type: "string", description: "Optional reason for mid-range confidence" },
          learnings: {
            type: "string",
            description: "Required when confidence is 0 or 100 (completing the goal)"
          }
        },
        required: ["goal_path", "confidence_percentage"],
        additionalProperties: false
      }
    }.freeze

    DESCRIPTIONS = {
      "list_teammates" => "List teammates in the organization (directory). Prefer paths from results over numeric ids.",
      "list_goals" => "List goals visible to you, optionally only those needing a current-week confidence check-in.",
      "list_observations" => "List published observations (OGOs) visible to you.",
      "search_organization" => "Search people, assignments, abilities, titles, and observations in the org.",
      "create_draft_observation" => "Create a draft OGO only (never publishes). Use observee_path from other tools.",
      "set_current_week_goal_confidence" => "Set goal confidence for the current Monday week only. 0% or 100% requires learnings."
    }.freeze

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

    def description_for(name)
      DESCRIPTIONS[name.to_s]
    end

    def input_schema_for(name)
      INPUT_SCHEMAS[name.to_s]
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
