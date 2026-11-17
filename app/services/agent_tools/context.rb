# frozen_string_literal: true

module AgentTools
  # Caller identity for tool invocation. AuthZ uses the same Pundit user as controllers.
  #
  # mutation_gate:
  # - :host_confirmed — UI already confirmed (Ask OG); mutating tools may write immediately
  # - :tool_pending — MCP / agents; mutating tools must preview → confirm_goal_change (or draft→start)
  class Context
    MUTATION_GATES = %i[host_confirmed tool_pending].freeze

    attr_reader :organization, :person, :company_teammate, :pundit_user, :mutation_gate

    def initialize(organization:, person:, company_teammate:, pundit_user: nil, mutation_gate: :host_confirmed)
      @organization = organization
      @person = person
      @company_teammate = company_teammate
      @pundit_user = pundit_user || OpenStruct.new(user: company_teammate, impersonating_teammate: nil)
      gate = mutation_gate.to_sym
      gate = :host_confirmed unless MUTATION_GATES.include?(gate)
      @mutation_gate = gate
    end

    def tool_pending_mutations?
      mutation_gate == :tool_pending
    end

    def authorize!(record, query)
      policy = Pundit.policy!(pundit_user, record)
      return true if policy.public_send(query)

      raise ::AgentTools::NotAuthorized, "Not authorized to #{query} on #{record.class.name}"
    end

    def policy_scope(scope)
      Pundit.policy_scope!(pundit_user, scope)
    end
  end
end
