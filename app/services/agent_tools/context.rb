# frozen_string_literal: true

module AgentTools
  # Caller identity for tool invocation. AuthZ uses the same Pundit user as controllers.
  class Context
    attr_reader :organization, :person, :company_teammate, :pundit_user

    def initialize(organization:, person:, company_teammate:, pundit_user: nil)
      @organization = organization
      @person = person
      @company_teammate = company_teammate
      @pundit_user = pundit_user || OpenStruct.new(user: company_teammate, impersonating_teammate: nil)
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
