# frozen_string_literal: true

module Assistant
  # Runs a user-confirmed proposed write action via AgentTools only.
  class ConfirmProposedAction
    def self.call(...) = new(...).call

    def initialize(og_consultation:, action_index:, context:)
      @consultation = og_consultation
      @action_index = action_index.to_i
      @context = context
    end

    def call
      result = @consultation.result
      return Result.err("Ask OG result missing") unless result.is_a?(AskOgResult)
      return Result.err("Ask OG is not completed") unless @consultation.status == "completed"

      actions = Array(result.proposed_actions)
      action = actions[@action_index]
      return Result.err("Unknown action") if action.blank?

      tool = action["tool"].to_s
      return Result.err("Invalid tool") unless AgentTools::Registry.write_tool?(tool)

      args = (action["args"].is_a?(Hash) ? action["args"] : {}).symbolize_keys
      tool_result = AgentTools::Registry.invoke(tool, context: @context, **args)
      return Result.err(tool_result.error) unless tool_result.ok?

      result.increment!(:confirms_count)
      Result.ok(tool_result.data)
    end
  end
end
