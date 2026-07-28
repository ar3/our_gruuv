# frozen_string_literal: true

module Assistant
  # Builds AgentTools::Context from org + teammate (same Pundit user shape as controllers).
  class ContextBuilder
    def self.call(organization:, company_teammate:, impersonating_teammate: nil)
      new(
        organization: organization,
        company_teammate: company_teammate,
        impersonating_teammate: impersonating_teammate
      ).call
    end

    def initialize(organization:, company_teammate:, impersonating_teammate: nil)
      @organization = organization
      @company_teammate = company_teammate
      @impersonating_teammate = impersonating_teammate
    end

    def call
      AgentTools::Context.new(
        organization: @organization,
        person: @company_teammate.person,
        company_teammate: @company_teammate,
        pundit_user: OpenStruct.new(
          user: @company_teammate,
          impersonating_teammate: @impersonating_teammate
        )
      )
    end
  end
end
