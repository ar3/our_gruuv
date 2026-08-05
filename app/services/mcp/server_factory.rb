# frozen_string_literal: true

module Mcp
  # Builds an MCP::Server whose tools are 1:1 with AgentTools::Registry.
  class ServerFactory
    SERVER_NAME = "ourgruuv"
    SERVER_VERSION = "1.0.0"
    INSTRUCTIONS = <<~TEXT.freeze
      OurGruuv MCP: query teammates, goals, assignments, abilities, observations (OGOs),
      sitemap pages, and org search as the authenticated teammate. Prefer path values
      from tool results over numeric ids. Use list_sitemap for navigation / where-to-go
      answers; do not invent pages. list_goals rows include owned_by_me, created_by_me,
      and owner details; optional filters AND together. list_assignments and
      list_abilities default to detail=expensive (full body fields); use detail=minimal
      for titles/names only. create_draft_observation never publishes.
      set_current_week_goal_confidence only updates the current Monday week; 0% or 100%
      requires learnings.
    TEXT

    def self.build(agent_tools_context:)
      new(agent_tools_context: agent_tools_context).build
    end

    def initialize(agent_tools_context:)
      @agent_tools_context = agent_tools_context
    end

    def build
      MCP::Server.new(
        name: SERVER_NAME,
        title: "OurGruuv",
        version: SERVER_VERSION,
        instructions: INSTRUCTIONS,
        tools: tool_classes,
        server_context: { agent_tools_context: @agent_tools_context }
      )
    end

    private

    def tool_classes
      AgentTools::Registry.tool_names.map { |name| define_tool(name) }
    end

    def define_tool(name)
      schema = AgentTools::Registry.input_schema_for(name) || { type: "object", properties: {} }
      description = AgentTools::Registry.description_for(name) || name
      write = AgentTools::Registry.write_tool?(name)

      MCP::Tool.define(
        name: name,
        title: AgentTools::Registry.title_for(name) || name,
        description: description,
        input_schema: schema,
        annotations: {
          read_only_hint: !write,
          destructive_hint: write,
          idempotent_hint: !write
        }
      ) do |server_context:, **args|
        context = server_context && server_context[:agent_tools_context]
        if context.nil?
          MCP::Tool::Response.new(
            [{ type: "text", text: JSON.pretty_generate({ ok: false, error: "Missing auth context", error_code: "not_authorized" }) }],
            error: true
          )
        else
          Mcp::ToolBridge.call(tool_name: name, context: context, **args)
        end
      end
    end
  end
end
