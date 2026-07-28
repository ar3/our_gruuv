# frozen_string_literal: true

module Mcp
  # Thin bridge: MCP tool call → AgentTools::Registry.invoke.
  # Injects MCP provenance for draft OGOs. No domain logic here.
  class ToolBridge
    MCP_WRITE_DEFAULTS = {
      "create_draft_observation" => {
        trigger_source: "mcp",
        trigger_type: "mcp_assistant",
        created_as_type: "mcp"
      }
    }.freeze

    def self.call(tool_name:, context:, **args)
      new(tool_name: tool_name, context: context, args: args).call
    end

    def initialize(tool_name:, context:, args:)
      @tool_name = tool_name.to_s
      @context = context
      @args = args
    end

    def call
      extras = MCP_WRITE_DEFAULTS[@tool_name] || {}
      # Client must not override provenance for MCP-originated drafts.
      cleaned = @args.except(:trigger_source, :trigger_type, :created_as_type, "trigger_source", "trigger_type", "created_as_type")
      result = AgentTools::Registry.invoke(@tool_name, context: @context, **cleaned, **extras)

      if result.ok?
        MCP::Tool::Response.new([
          {
            type: "text",
            text: JSON.pretty_generate({ ok: true, data: result.data })
          }
        ])
      else
        MCP::Tool::Response.new(
          [
            {
              type: "text",
              text: JSON.pretty_generate({
                ok: false,
                error: result.error,
                error_code: result.error_code
              })
            }
          ],
          error: true
        )
      end
    rescue AgentTools::UnknownTool => e
      MCP::Tool::Response.new(
        [{ type: "text", text: JSON.pretty_generate({ ok: false, error: e.message, error_code: "unknown_tool" }) }],
        error: true
      )
    rescue StandardError => e
      Rails.logger.warn("Mcp::ToolBridge failed: #{e.class}: #{e.message}")
      MCP::Tool::Response.new(
        [{ type: "text", text: JSON.pretty_generate({ ok: false, error: e.message, error_code: "internal_error" }) }],
        error: true
      )
    end
  end
end
