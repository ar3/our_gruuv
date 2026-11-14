# frozen_string_literal: true

module Organizations
  # Admin hub: how to call OG via MCP and HTTP (mint FR link, tokens).
  class IntegrationsController < OrganizationNamespaceBaseController
    def show
      authorize organization, :show?

      @mcp_url = "#{request.base_url}/mcp"
      @mint_url = "#{request.base_url}/api/feedback_requests/mint"
      @mcp_tokens_path = organization_mcp_access_tokens_path(organization)
    end
  end
end
